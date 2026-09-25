@IsTest
private class CaseTriageTest {

    @TestSetup
    static void setup() {
        insert new List<Case>{
            new Case(Subject = 'URGENT: portal outage', Description = 'Site is down, we cannot log in. This is unacceptable and terrible.', Origin = 'Email'),
            new Case(Subject = 'Question about invoice', Description = 'I think I was overcharged on my last invoice.', Origin = 'Web'),
            new Case(Subject = 'Hello', Description = 'General question about hours.', Origin = 'Phone')
        };
    }

    @IsTest
    static void engineClassifiesCriticalOutage() {
        CaseTriageEngine.TriageResult r = new CaseTriageEngine().triage('URGENT: portal outage', 'Site is down, unacceptable and terrible');
        Assert.areEqual('Technical', r.category);
        Assert.areEqual('Critical', r.priority);
        Assert.areEqual('Negative', r.sentiment);
        Assert.isTrue(r.nextBestAction.startsWith('Escalate'));
    }

    @IsTest
    static void engineHandlesBillingAndGeneral() {
        CaseTriageEngine engine = new CaseTriageEngine();
        Assert.areEqual('Billing', engine.triage('Question about invoice', 'overcharged').category);
        CaseTriageEngine.TriageResult general = engine.triage(null, null);
        Assert.areEqual('General', general.category);
        Assert.areEqual('Low', general.priority);
    }

    @IsTest
    static void invocableAppliesPriority() {
        Case c = [SELECT Id FROM Case WHERE Subject LIKE 'URGENT%' LIMIT 1];
        TriageCaseAction.Request req = new TriageCaseAction.Request();
        req.caseId = c.Id;
        req.applyToCase = true;

        Test.startTest();
        List<TriageCaseAction.Response> res = TriageCaseAction.triage(new List<TriageCaseAction.Request>{ req });
        Test.stopTest();

        Assert.areEqual('Critical', res[0].priority);
        Assert.isTrue(res[0].agentMessage.contains('Recommended next step'));
        Assert.areEqual('High', [SELECT Priority FROM Case WHERE Id = :c.Id].Priority);
    }

    @IsTest
    static void invocableHandlesMissingCase() {
        Case c = [SELECT Id FROM Case LIMIT 1];
        Id missing = c.Id;
        delete c;
        TriageCaseAction.Request req = new TriageCaseAction.Request();
        req.caseId = missing;
        List<TriageCaseAction.Response> res = TriageCaseAction.triage(new List<TriageCaseAction.Request>{ req });
        Assert.isTrue(res[0].agentMessage.contains('could not find'));
    }

    @IsTest
    static void promptContextAndController() {
        Case c = [SELECT Id FROM Case WHERE Subject = 'Question about invoice' LIMIT 1];
        insert new CaseComment(ParentId = c.Id, CommentBody = 'Customer attached invoice #1001.');

        CaseContextForPrompt.Request req = new CaseContextForPrompt.Request();
        req.relatedCase = c;
        String prompt = CaseContextForPrompt.build(new List<CaseContextForPrompt.Request>{ req })[0].prompt;
        Assert.isTrue(prompt.contains('Triage: Billing'));
        Assert.isTrue(prompt.contains('invoice #1001'));

        Assert.areEqual('Billing', CaseTriageController.getTriage(c.Id).category);
        CaseTriageController.applyTriage(c.Id);
        Assert.areEqual('Low', CaseRoutingService.toCasePriority('Low'));
    }
}
