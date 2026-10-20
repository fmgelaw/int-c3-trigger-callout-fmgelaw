/**
 * Queueable Apex class for processing News Category records with pagination support
 */
public class NewsCategoryQueueable implements Queueable, Database.AllowsCallouts {
    // Static variable for maximum pages to fetch
    private static final Integer MAX_PAGES = 3;
    private static final String LOG_SCENARIO = 'News Category Sync';
    private static final String LOG_TAG = 'NewsCategoryQueueable';

    private News_Category__c category;
    private Integer currentPage = 1;
    private List<News_Category__c> remainingCategories = new List<News_Category__c>();
    private String originalTransactionId;

    /**
     * Constructor - starts a new sync from page 1 for a single category, with no others queued behind it
     * @param category The News_Category__c record
     */
    public NewsCategoryQueueable(News_Category__c category) {
        this(category, 1, new List<News_Category__c>());
    }

    /**
     * Constructor - entry point for syncing a list of categories.
     * Processes categories one at a time, chaining to the next once each finishes,
     * instead of enqueueing a job per category up front (which could hit the
     * 50-jobs-per-transaction limit on a large list).
     * @param categoriesToSync Categories still waiting to be synced; must not be empty
     */
    public NewsCategoryQueueable(List<News_Category__c> categoriesToSync) {
        this(categoriesToSync[0], 1, categoriesExcludingFirst(categoriesToSync));
    }

    /**
     * Constructor
     * @param category The News_Category__c record currently being synced
     * @param currentPage Current page to process
     * @param remainingCategories Categories still waiting their turn once this one finishes
     */
    public NewsCategoryQueueable(News_Category__c category, Integer currentPage, List<News_Category__c> remainingCategories) {
        // TODO: Initialize with category and current page
        this.category = category;
        this.currentPage = currentPage;
        this.remainingCategories = remainingCategories;
    }

    /**
     * Sets the Nebula Logger transaction id this job's logs should link back to (e.g. the
     * trigger transaction that kicked off the sync). Returns this instance so it can be
     * chained right before System.enqueueJob.
     * @param originalTransactionId The Nebula Logger transaction id this chain should link back to
     * @return This instance, for chaining
     */
    public NewsCategoryQueueable withOriginalTransactionId(String originalTransactionId) {
        this.originalTransactionId = originalTransactionId;
        return this;
    }

    /**
     * @param categories A list with at least one element
     * @return A new list containing every element except the first
     */
    private static List<News_Category__c> categoriesExcludingFirst(List<News_Category__c> categories) {
        List<News_Category__c> remainder = categories.clone();
        remainder.remove(0);
        return remainder;
    }

    /**
     * Sets the scenario for this transaction and links it back to whichever transaction
     * originally kicked off this sync (the trigger, or an earlier hop in this same chain).
     * If no id was passed in, this hop is the root - capture its own id so any hop chained
     * from here can still link back to it.
     */
    private void beginLoggingScope() {
        Nebula.Logger.setScenario(LOG_SCENARIO);
        if (String.isBlank(originalTransactionId)) {
            originalTransactionId = Nebula.Logger.getTransactionId();
        } else if (originalTransactionId != Nebula.Logger.getTransactionId()) {
            Nebula.Logger.setParentLogTransactionId(originalTransactionId);
        }
    }

    /**
     * Execute method for the queueable job
     * @param context The QueueableContext
     */
    public void execute(QueueableContext context) {
        beginLoggingScope();
        Nebula.Logger.info(
            'NewsCategoryQueueable started for category ' + category.Id + ' (' + category.Name + ') page ' + currentPage
        ).addTag(LOG_TAG);

        // IMPORTANT: Create a separate instance of the category for updates
        News_Category__c updatedCategory = new News_Category__c(Id = category.Id);

        try {
            // TODO: Implement execute method
            // - Call NewsAPI for the current page
            // - Convert API articles to Salesforce articles using NewsAPIResponse.convertToSObject
            // - Add category reference to each article
            // - Insert the articles
            // - Check if reached MAX_PAGES or no more articles
            // HINT: When requeuing the job check if tests are running
            // - Update category with last synced date and sync flag = false

            // Call NewsAPI for the current page
            NewsAPIResponse response = NewsAPIService.getTopHeadlinesByCategory(category.Name, currentPage, category.Country__c);

            // Convert API articles to Salesforce articles using NewsAPIResponse.convertToSObject,
            // adding the category reference to each article
            List<Article__c> articlesToInsert = new List<Article__c>();
            if (response.articles != null) {
                for (NewsAPIResponse.Article apiArticle : response.articles) {
                    Article__c articleRecord = NewsAPIResponse.convertToSObject(apiArticle);
                    articleRecord.News_Category__c = category.Id;
                    articleRecord.Category__c = category.Name;
                    articleRecord.Country__c = category.Country__c;
                    articlesToInsert.add(articleRecord);
                }
            }

            // Insert the articles - wrapped separately from the callout so a DML failure
            // (e.g. a validation rule on Article__c) is distinguishable from an API failure
            if (!articlesToInsert.isEmpty()) {
                try {
                    insert articlesToInsert;
                } catch (DmlException de) {
                    Nebula.Logger.error(
                        'Failed to insert articles for category ' + category.Id + ' page ' + currentPage, de
                    ).addTag(LOG_TAG);
                    throw de;
                }
            }

            // Calculate the optimal number of pages to sync based on the API's total results
            Integer totalPages = (response.totalResults != null && response.totalResults > 0)
                ? Integer.valueOf(Math.ceil(response.totalResults / (Decimal) NewsAPIService.PAGE_SIZE))
                : 0;

            // An empty current page always stops pagination, even if totalResults claims more remain -
            // the API's reported total can be inflated/inaccurate, so real data wins over metadata.
            Boolean currentPageHasArticles = !articlesToInsert.isEmpty();
            Boolean categoryDone = !hasMorePages(currentPage, totalPages, currentPageHasArticles);
            if (categoryDone) {
                // All pages for this category are done - update page count, last synced date, and sync flag = false.
                // Pages__c records pages actually processed (pages that returned articles), not the
                // totalResults-based estimate - an empty page ends the chain early and isn't counted.
                // An intermediate page persists nothing - these finished-state fields are written together, once.
                updatedCategory.Pages__c = currentPageHasArticles ? currentPage : currentPage - 1;
                updatedCategory.Last_Synced__c = Datetime.now();
                updatedCategory.Sync__c = false;
                updateCategory(updatedCategory, currentPage);

                // This category is done - move on to the next one in the list, if any
                if (!remainingCategories.isEmpty() && !Test.isRunningTest()) {
                    System.enqueueJob(
                        new NewsCategoryQueueable(remainingCategories).withOriginalTransactionId(originalTransactionId)
                    );
                }
            } else if (!Test.isRunningTest()) {
                // Not yet done - fetch the next page of this same category
                System.enqueueJob(
                    new NewsCategoryQueueable(category, currentPage + 1, remainingCategories)
                        .withOriginalTransactionId(originalTransactionId)
                );
            }

            Nebula.Logger.info(
                'NewsCategoryQueueable completed successfully for category ' + category.Id + ' page ' + currentPage
            ).addTag(LOG_TAG);
        } catch (Exception e) {
            // TODO: Handle errors
            // - Update category with error information
            // - Log error to debug logs

            // Log error to debug logs
            Nebula.Logger.error(
                'NewsCategoryQueueable failed for category ' + category.Id + ' on page ' + currentPage, e
            ).addTag(LOG_TAG);

            // Update category with error information - guarded so a DML failure here
            // (e.g. the category was deleted concurrently) can't stop the list from chaining
            try {
                updatedCategory.Sync__c = false;
                update updatedCategory;
            } catch (Exception updateEx) {
                Nebula.Logger.error(
                    'Failed to reset Sync__c on category ' + category.Id + ' after sync error', updateEx
                ).addTag(LOG_TAG);
            }

            // Creates an error record; a separate record is created for each run.
            // Message includes the exception type (NewsAPIException vs. DmlException vs. other)
            // so failures can be triaged without reproducing them.
            // Guarded so a failure inserting the error record itself can't stop the list from chaining
            try {
                insert new News_Sync_Error__c(
                    News_Category__c = category.Id,
                    Page__c = currentPage,
                    Message__c = e.getTypeName() + ': ' + e.getMessage()
                );
            } catch (Exception insertEx) {
                Nebula.Logger.error(
                    'Failed to insert News_Sync_Error__c for category ' + category.Id, insertEx
                ).addTag(LOG_TAG);
            }

            Nebula.Logger.info(
                'NewsCategoryQueueable ended with error for category ' + category.Id + ' page ' + currentPage
            ).addTag(LOG_TAG);

            // This category failed - don't let it block the rest of the list from syncing
            if (!remainingCategories.isEmpty() && !Test.isRunningTest()) {
                System.enqueueJob(
                    new NewsCategoryQueueable(remainingCategories).withOriginalTransactionId(originalTransactionId)
                );
            }
        } finally {
            Nebula.Logger.saveLog();
        }
    }

    /**
     * Decides whether this category has another page to fetch. An empty current page always
     * stops pagination, even if totalResults claims more remain - the API's reported total can
     * be inflated/inaccurate, so real data wins over metadata.
     * @param currentPage The page just processed
     * @param totalPages Page count estimated from the response's totalResults
     * @param currentPageHasArticles Whether the page just processed returned any articles
     * @return True if the next page of this category should be fetched
     */
    @TestVisible
    private static Boolean hasMorePages(Integer currentPage, Integer totalPages, Boolean currentPageHasArticles) {
        Boolean morePagesRemain = currentPage < totalPages;
        Boolean underPageCap = currentPage < MAX_PAGES;
        return underPageCap && currentPageHasArticles && morePagesRemain;
    }

    /**
     * Updates the category record, wrapped separately from the callout/insert above so a
     * DML failure here (distinct partial-success semantics from the article insert) is
     * logged at its own point of failure.
     */
    private void updateCategory(News_Category__c categoryToUpdate, Integer page) {
        try {
            update categoryToUpdate;
        } catch (DmlException de) {
            Nebula.Logger.error(
                'Failed to update category ' + categoryToUpdate.Id + ' after page ' + page, de
            ).addTag(LOG_TAG);
            throw de;
        }
    }
}
