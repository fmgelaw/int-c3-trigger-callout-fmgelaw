@IsTest
private class NewsAPIServiceTest {
    
    @IsTest
    static void testGetTopHeadlinesByCategorySuccess() {
        // Set up the mock
        Test.setMock(HttpCalloutMock.class, NewsAPIMock.createSuccessMock());
        
        Test.startTest();
        
        // Test with valid parameters
        NewsAPIResponse response = NewsAPIService.getTopHeadlinesByCategory('technology', 1);
        
        Test.stopTest();
        
        // Verify the response
        Assert.areEqual('ok', response.status, 'Response status should be ok');
        Assert.areEqual(2, response.totalResults, 'Should have 2 articles');
        Assert.areEqual(2, response.articles.size(), 'Should have 2 articles');
    }
    
    // page < 1 throws NewsAPIException (no default fallback), so this expects the exception, not a response.
    @IsTest
    static void testGetTopHeadlinesByCategoryWithInvalidPage() {
        Test.startTest();

        NewsAPIService.NewsAPIException thrown;
        try {
            NewsAPIService.getTopHeadlinesByCategory('technology', 0);
            Assert.fail('Expected a NewsAPIException for an invalid page');
        } catch (NewsAPIService.NewsAPIException e) {
            thrown = e;
        }

        Test.stopTest();

        Assert.areEqual('Page must be a positive integer.', thrown.getMessage(),
            'Exception message should identify the invalid page');
    }
}