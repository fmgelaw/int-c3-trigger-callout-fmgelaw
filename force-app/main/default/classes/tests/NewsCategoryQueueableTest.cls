@IsTest
private class NewsCategoryQueueableTest {

    /**
     * A response that claims more results than it actually returns - totalResults = 60
     * implies 3 pages at PAGE_SIZE 20, but the articles array is empty.
     */
    private static NewsAPIMock createInflatedTotalEmptyPageMock() {
        String body = '{' +
            '"status": "ok",' +
            '"totalResults": 60,' +
            '"articles": []' +
        '}';
        return new NewsAPIMock(200, body);
    }

    /**
     * A full page (2 articles) with a configurable totalResults, so a test can make the
     * API claim more pages remain than the page just fetched.
     */
    private static NewsAPIMock createPageWithArticlesMock(Integer totalResults) {
        String body = '{' +
            '"status": "ok",' +
            '"totalResults": ' + totalResults + ',' +
            '"articles": [' +
                '{"source": {"id": "test-1", "name": "Test Source 1"}, "title": "Test Article 1", "url": "https://test1.com", "publishedAt": "2024-03-28T12:00:00Z"},' +
                '{"source": {"id": "test-2", "name": "Test Source 2"}, "title": "Test Article 2", "url": "https://test2.com", "publishedAt": "2024-03-28T13:00:00Z"}' +
            ']' +
        '}';
        return new NewsAPIMock(200, body);
    }

    /**
     * Category for the later-page tests, which call execute() directly instead of enqueueing -
     * inserted here so no uncommitted DML is pending when execute() makes its callout.
     * Sync__c = false so the trigger doesn't enqueue a job of its own.
     */
    @TestSetup
    static void setupLaterPageCategory() {
        insert new News_Category__c(Name = 'Sports', Sync__c = false);
    }

    private static News_Category__c getCategory(String name) {
        return [SELECT Id, Name, Country__c FROM News_Category__c WHERE Name = :name];
    }

    /**
     * Inserted with Sync__c = false so the trigger doesn't enqueue its own job -
     * each test enqueues the queueable directly at the page it needs.
     */
    private static News_Category__c createCategory(String name) {
        News_Category__c category = new News_Category__c(Name = name, Sync__c = false);
        insert category;
        return category;
    }

    @IsTest
    static void testEmptyPageTwoRecordsPagesActuallyProcessed() {
        // Page 1 succeeded earlier in the chain; page 2 claims 60 results but returns no articles
        Test.setMock(HttpCalloutMock.class, createInflatedTotalEmptyPageMock());
        News_Category__c category = createCategory('Technology');

        Test.startTest();
        System.enqueueJob(new NewsCategoryQueueable(category, 2, new List<News_Category__c>()));
        Test.stopTest();

        News_Category__c updatedCategory = [
            SELECT Id, Pages__c, Last_Synced__c, Sync__c
            FROM News_Category__c
            WHERE Id = :category.Id
        ];
        Assert.areEqual(1, updatedCategory.Pages__c,
            'Pages__c should count only the 1 page that returned articles, not the 3 estimated from totalResults');
        Assert.isNotNull(updatedCategory.Last_Synced__c, 'An empty page should still complete the sync');
        Assert.areEqual(false, updatedCategory.Sync__c, 'Sync__c should be reset to false');

        Assert.areEqual(0, [SELECT COUNT() FROM Article__c WHERE News_Category__c = :category.Id],
            'No articles should be created from an empty page');
        Assert.areEqual(0, [SELECT COUNT() FROM News_Sync_Error__c WHERE News_Category__c = :category.Id],
            'An empty page is a normal end of results, not an error');
    }

    @IsTest
    static void testEmptyFirstPageRecordsZeroPages() {
        // Edge case: the very first page claims 60 results but returns no articles
        Test.setMock(HttpCalloutMock.class, createInflatedTotalEmptyPageMock());
        News_Category__c category = createCategory('Science');

        Test.startTest();
        System.enqueueJob(new NewsCategoryQueueable(category));
        Test.stopTest();

        News_Category__c updatedCategory = [
            SELECT Id, Pages__c, Sync__c
            FROM News_Category__c
            WHERE Id = :category.Id
        ];
        Assert.areEqual(0, updatedCategory.Pages__c,
            'Pages__c should be 0 when no page returned articles, regardless of totalResults');
        Assert.areEqual(false, updatedCategory.Sync__c, 'Sync__c should be reset to false');
    }

    @IsTest
    static void testFullPageRecordsPagesProcessed() {
        // Positive path: a page that returns all its results counts as processed
        Test.setMock(HttpCalloutMock.class, NewsAPIMock.createSuccessMock());
        News_Category__c category = createCategory('Business');

        Test.startTest();
        System.enqueueJob(new NewsCategoryQueueable(category));
        Test.stopTest();

        News_Category__c updatedCategory = [
            SELECT Id, Pages__c
            FROM News_Category__c
            WHERE Id = :category.Id
        ];
        Assert.areEqual(1, updatedCategory.Pages__c, 'Pages__c should be 1 after a single page with articles');
    }

    // ---- Later pages: execute() is called directly at the page under test, since the
    // ---- Test.isRunningTest() guard suppresses the real continuation.

    @IsTest
    static void testLaterPageWithMoreResultsPersistsNothingYet() {
        // Page 2 of 3 (totalResults 60) returns articles - the category isn't finished yet
        Test.setMock(HttpCalloutMock.class, createPageWithArticlesMock(60));
        News_Category__c sports = getCategory('Sports');
        NewsCategoryQueueable job = new NewsCategoryQueueable(sports, 2, new List<News_Category__c>());

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        News_Category__c updatedCategory = [SELECT Pages__c, Last_Synced__c FROM News_Category__c WHERE Id = :sports.Id];
        Assert.isNull(updatedCategory.Last_Synced__c, 'An intermediate page should not mark the category as synced');
        Assert.isNull(updatedCategory.Pages__c, 'An intermediate page should not persist a page count');
        Assert.areEqual(2, [SELECT COUNT() FROM Article__c WHERE News_Category__c = :sports.Id],
            'Articles from the intermediate page should still be inserted');
    }

    @IsTest
    static void testPageAtCapFinishesCategory() {
        // Page 3 (MAX_PAGES) returns articles and the API claims more remain - the cap must still stop it
        Test.setMock(HttpCalloutMock.class, createPageWithArticlesMock(200));
        News_Category__c sports = getCategory('Sports');
        NewsCategoryQueueable job = new NewsCategoryQueueable(sports, 3, new List<News_Category__c>());

        Test.startTest();
        job.execute(null);
        Test.stopTest();

        News_Category__c updatedCategory = [SELECT Pages__c, Last_Synced__c, Sync__c FROM News_Category__c WHERE Id = :sports.Id];
        Assert.areEqual(3, updatedCategory.Pages__c, 'Pages__c should record the pages processed up to the cap');
        Assert.isNotNull(updatedCategory.Last_Synced__c, 'The category should be marked as synced once the cap is reached');
        Assert.areEqual(false, updatedCategory.Sync__c, 'Sync__c should be reset to false');
    }

    // ---- hasMorePages: the next-page decision on its own, no callout or async needed

    @IsTest
    static void testHasMorePagesWhenUnderCapWithArticlesAndMoreReported() {
        Assert.isTrue(NewsCategoryQueueable.hasMorePages(1, 3, true), 'Page 1 of 3 with articles should continue');
        Assert.isTrue(NewsCategoryQueueable.hasMorePages(2, 3, true), 'Page 2 of 3 with articles should continue');
    }

    @IsTest
    static void testHasMorePagesStopsAtBoundaries() {
        // 3 = NewsCategoryQueueable.MAX_PAGES
        Assert.isFalse(NewsCategoryQueueable.hasMorePages(3, 8, true),
            'Reaching MAX_PAGES should stop even if the API reports more pages');
        Assert.isFalse(NewsCategoryQueueable.hasMorePages(2, 2, true), 'The last reported page should stop');
        Assert.isFalse(NewsCategoryQueueable.hasMorePages(1, 3, false),
            'An empty page should stop even if the API reports more pages');
        Assert.isFalse(NewsCategoryQueueable.hasMorePages(1, 0, true), 'A totalResults of 0 should stop');
    }
}
