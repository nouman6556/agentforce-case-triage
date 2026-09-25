public with sharing class CaseTriageController {
    @AuraEnabled(cacheable=true)
    public static CaseTriageEngine.TriageResult getTriage(Id caseId) {
        Case c = [SELECT Subject, Description FROM Case WHERE Id = :caseId WITH USER_MODE];
        return new CaseTriageEngine().triage(c.Subject, c.Description);
    }

    @AuraEnabled
    public static void applyTriage(Id caseId) {
        TriageCaseAction.Request req = new TriageCaseAction.Request();
        req.caseId = caseId;
        req.applyToCase = true;
        TriageCaseAction.triage(new List<TriageCaseAction.Request>{ req });
    }
}
