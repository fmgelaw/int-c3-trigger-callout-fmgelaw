/**
 * Handler class for NewsCategoryTrigger
 */
public with sharing class NewsCategoryTriggerHandler {
    private static final String LOG_SCENARIO = 'News Category Sync';
    private static final String LOG_TAG = 'NewsCategoryTriggerHandler';

    private static void beginLoggingScope() {
        Nebula.Logger.setScenario(LOG_SCENARIO);
    }

    /**
     * Handles after insert events for News_Category__c
     * Uses Queueable for callouts when Sync__c is true
     * @param newRecords List of newly inserted News_Category__c records
     */
    public static void handleInsert(List<News_Category__c> newRecords) {
        // TODO: Implement insert handler
        // - Filter categories that need to be synced (Sync__c = true)
        // - Call queueable method for callouts

        beginLoggingScope();
        try {
            Nebula.Logger.info('handleInsert called for ' + newRecords.size() + ' News_Category__c record(s)').addTag(LOG_TAG);

            // Filter categories that need to be synced (Sync__c = true)
            List<News_Category__c> categoriesToSync = new List<News_Category__c>();
            for (News_Category__c category : newRecords) {
                if (category.Sync__c) {
                    categoriesToSync.add(category);
                }
            }

            Nebula.Logger.info(
                categoriesToSync.size() + ' of ' + newRecords.size() + ' inserted record(s) need syncing'
            ).addTag(LOG_TAG);

            // Call queueable method for callouts
            syncCategoriesWithQueueable(categoriesToSync);
        } finally {
            Nebula.Logger.saveLog();
        }
    }

    /**
     * Handles after update events for News_Category__c
     * Uses Queueable Apex for callouts when Sync__c is true
     * @param newRecords List of updated News_Category__c records
     * @param oldMap Map of old record states
     */
    public static void handleUpdate(List<News_Category__c> newRecords, Map<Id, News_Category__c> oldMap) {
        // TODO: Implement update handler
        // - Filter categories that need to be synced (Sync__c changed from false to true)
        // - Call queueable method for callouts

        beginLoggingScope();
        try {
            Nebula.Logger.info('handleUpdate called for ' + newRecords.size() + ' News_Category__c record(s)').addTag(LOG_TAG);

            // Filter categories that need to be synced (Sync__c changed from false to true)
            List<News_Category__c> categoriesToSync = new List<News_Category__c>();
            for (News_Category__c category : newRecords) {
                News_Category__c oldCategory = oldMap.get(category.Id);
                if (category.Sync__c && !oldCategory.Sync__c) {
                    categoriesToSync.add(category);
                }
            }

            Nebula.Logger.info(
                categoriesToSync.size() + ' of ' + newRecords.size() + ' updated record(s) flipped Sync__c false -> true'
            ).addTag(LOG_TAG);

            // Call queueable method for callouts
            syncCategoriesWithQueueable(categoriesToSync);
        } finally {
            Nebula.Logger.saveLog();
        }
    }

    /**
     * Queueable method to sync categories using the NewsAPI
     * @param categoriesToSync List of News_Category__c records to sync
     */
    private static void syncCategoriesWithQueueable(List<News_Category__c> categoriesToSync) {
        // TODO: Implement queueable job enqueuing
        // - Create and enqueue NewsCategoryQueueable job for each category

        if (!categoriesToSync.isEmpty()) {
            // Pass this transaction's id through so the async queueable chain can link its
            // logs back to the trigger transaction that kicked off the sync
            System.enqueueJob(
                new NewsCategoryQueueable(categoriesToSync).withOriginalTransactionId(Nebula.Logger.getTransactionId())
            );
        }
    }
}
