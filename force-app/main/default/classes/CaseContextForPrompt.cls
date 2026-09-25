/**
 * Grounding for the Prompt Builder template "Case_Reply_Draft".
 * Invoked from the template as an Apex merge field. It gives the LLM a compact,
 * PII-minimised view of the case, the triage result and recent comments.
 */
public with sharing class CaseContextForPrompt {

    public class Request {
        @InvocableVariable(required=true) public Case relatedCase; // Prompt Builder passes the record
    }

    public class Response {
        @InvocableVariable public String prompt;
    }

    @InvocableMethod(label='Case Context for Prompt' description='Builds grounded context for the case reply prompt template')
    public static List<Response> build(List<Request> requests) {
        List<Response> out = new List<Response>();
        CaseTriageEngine engine = new CaseTriageEngine();
        Set<Id> caseIds = new Set<Id>();
        for (Request req : requests) { caseIds.add(req.relatedCase.Id); }
        Map<Id, Case> cases = new Map<Id, Case>([
            SELECT Id, CaseNumber, Subject, Description, Status, Priority, Origin,
                (SELECT CommentBody, CreatedDate FROM CaseComments ORDER BY CreatedDate DESC LIMIT 3)
            FROM Case WHERE Id IN :caseIds WITH USER_MODE
        ]);
        for (Request req : requests) {
            Case c = cases.get(req.relatedCase.Id);
            CaseTriageEngine.TriageResult t = engine.triage(c.Subject, c.Description);
            List<String> lines = new List<String>{
                'Case ' + c.CaseNumber + ' | Status: ' + c.Status + ' | Channel: ' + c.Origin,
                'Subject: ' + c.Subject,
                'Issue: ' + (c.Description == null ? '(none)' : c.Description.abbreviate(1500)),
                'Triage: ' + t.category + ' / ' + t.priority + ' / sentiment ' + t.sentiment,
                'Recommended action: ' + t.nextBestAction
            };
            for (CaseComment cc : c.CaseComments) {
                lines.add('Recent comment (' + cc.CreatedDate.date() + '): ' + cc.CommentBody.abbreviate(400));
            }
            Response r = new Response();
            r.prompt = String.join(lines, '\n');
            out.add(r);
        }
        return out;
    }
}
