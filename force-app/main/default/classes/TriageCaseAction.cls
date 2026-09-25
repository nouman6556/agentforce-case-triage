/**
 * Agentforce custom action: "Triage Case".
 * Register in Agent Builder as an Apex action on the "Case Management" topic.
 * The agent passes a Case Id; the action returns category, priority and NBA,
 * and optionally applies them to the record.
 */
public with sharing class TriageCaseAction {

    public class Request {
        @InvocableVariable(label='Case Id' description='Id of the Case to triage' required=true)
        public Id caseId;
        @InvocableVariable(label='Apply to Case' description='If true, update Priority and route to queue')
        public Boolean applyToCase;
    }

    public class Response {
        @InvocableVariable(label='Category') public String category;
        @InvocableVariable(label='Priority') public String priority;
        @InvocableVariable(label='Sentiment') public String sentiment;
        @InvocableVariable(label='Urgency Score') public Integer urgencyScore;
        @InvocableVariable(label='Next Best Action') public String nextBestAction;
        @InvocableVariable(label='Target Queue') public String targetQueue;
        @InvocableVariable(label='Summary for Agent' description='Plain-language result the agent can relay') public String agentMessage;
    }

    @InvocableMethod(label='Triage Case' description='Classifies a case, scores urgency and recommends the next best action.' category='Agentforce')
    public static List<Response> triage(List<Request> requests) {
        Set<Id> ids = new Set<Id>();
        for (Request r : requests) { ids.add(r.caseId); }

        Map<Id, Case> cases = new Map<Id, Case>([
            SELECT Id, CaseNumber, Subject, Description, Priority, OwnerId
            FROM Case WHERE Id IN :ids WITH USER_MODE
        ]);

        CaseTriageEngine engine = new CaseTriageEngine();
        List<Response> responses = new List<Response>();
        List<Case> toUpdate = new List<Case>();
        Map<String, Id> queues = CaseRoutingService.queueIdsByDeveloperName();

        for (Request req : requests) {
            Case c = cases.get(req.caseId);
            Response res = new Response();
            if (c == null) {
                res.agentMessage = 'I could not find that case or you do not have access to it.';
                responses.add(res);
                continue;
            }
            CaseTriageEngine.TriageResult t = engine.triage(c.Subject, c.Description);
            res.category = t.category;
            res.priority = t.priority;
            res.sentiment = t.sentiment;
            res.urgencyScore = t.urgencyScore;
            res.nextBestAction = t.nextBestAction;
            res.targetQueue = t.targetQueue;
            res.agentMessage = 'Case ' + c.CaseNumber + ' looks like a ' + t.priority + ' priority ' + t.category
                + ' issue (sentiment: ' + t.sentiment + '). Recommended next step: ' + t.nextBestAction;

            if (req.applyToCase == true) {
                Case upd = new Case(Id = c.Id, Priority = CaseRoutingService.toCasePriority(t.priority));
                if (queues.containsKey(t.targetQueue)) {
                    upd.OwnerId = queues.get(t.targetQueue);
                }
                toUpdate.add(upd);
            }
            responses.add(res);
        }
        if (!toUpdate.isEmpty()) {
            update as user toUpdate;
        }
        return responses;
    }
}
