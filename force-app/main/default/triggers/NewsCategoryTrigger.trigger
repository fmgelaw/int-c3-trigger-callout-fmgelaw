/**
 * Trigger for News_Category__c object to sync news from API when Sync__c field is true
 */
trigger NewsCategoryTrigger on News_Category__c (after insert, after update) {
    // TODO: Implement trigger logic
    // - Call appropriate handler methods for insert and update contexts

    if (Trigger.isAfter && Trigger.isInsert) {
        NewsCategoryTriggerHandler.handleInsert(Trigger.new);
    }

    if (Trigger.isAfter && Trigger.isUpdate) {
        NewsCategoryTriggerHandler.handleUpdate(Trigger.new, Trigger.oldMap);
    }
}