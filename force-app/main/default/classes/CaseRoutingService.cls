public with sharing class CaseRoutingService {

    /** Maps engine priority to standard Case.Priority picklist values. */
    public static String toCasePriority(String enginePriority) {
        switch on enginePriority {
            when 'Critical', 'High' { return 'High'; }
            when 'Medium' { return 'Medium'; }
            when else { return 'Low'; }
        }
    }

    /** Case queues keyed by DeveloperName (one query per transaction). */
    public static Map<String, Id> queueIdsByDeveloperName() {
        Map<String, Id> result = new Map<String, Id>();
        for (QueueSobject qs : [
            SELECT Queue.Id, Queue.DeveloperName FROM QueueSobject WHERE SobjectType = 'Case'
        ]) {
            result.put(qs.Queue.DeveloperName, qs.Queue.Id);
        }
        return result;
    }
}
