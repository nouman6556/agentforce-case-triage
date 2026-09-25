/**
 * Deterministic triage engine shared by the Agentforce action, the LWC and Flow.
 * Scores a case's subject/description against weighted keyword signals to
 * produce a category, priority, sentiment and a next-best-action.
 * Keeping this deterministic makes the agent's behaviour testable and auditable;
 * the LLM (Prompt Builder) is used only to summarise and draft replies.
 */
public with sharing class CaseTriageEngine {

    public class TriageResult {
        @AuraEnabled public String category;
        @AuraEnabled public String priority;
        @AuraEnabled public String sentiment;
        @AuraEnabled public Integer urgencyScore;
        @AuraEnabled public String nextBestAction;
        @AuraEnabled public String targetQueue;
        @AuraEnabled public List<String> matchedSignals = new List<String>();
    }

    @TestVisible
    private static final Map<String, List<String>> CATEGORY_KEYWORDS = new Map<String, List<String>>{
        'Billing'       => new List<String>{ 'invoice', 'charge', 'refund', 'billing', 'payment', 'overcharged' },
        'Access'        => new List<String>{ 'login', 'password', 'locked', 'mfa', 'access', 'sso' },
        'Clinical'      => new List<String>{ 'prescription', 'appointment', 'referral', 'prior authorization', 'claim denied' },
        'Technical'     => new List<String>{ 'error', 'bug', 'crash', 'not working', 'outage', 'slow' }
    };

    private static final Map<String, Integer> URGENCY_SIGNALS = new Map<String, Integer>{
        'urgent' => 30, 'asap' => 25, 'immediately' => 25, 'outage' => 35,
        'cannot' => 15, 'down' => 20, 'legal' => 30, 'complaint' => 20, 'cancel' => 20
    };

    private static final Set<String> NEGATIVE_WORDS = new Set<String>{
        'angry', 'frustrated', 'unacceptable', 'terrible', 'worst', 'disappointed', 'complaint', 'cancel'
    };

    private static final Map<String, String> CATEGORY_QUEUE = new Map<String, String>{
        'Billing' => 'Billing_Support', 'Access' => 'Identity_Support',
        'Clinical' => 'Care_Coordination', 'Technical' => 'Tier_2_Technical', 'General' => 'General_Support'
    };

    public TriageResult triage(String subject, String description) {
        String text = ((subject == null ? '' : subject) + ' ' + (description == null ? '' : description)).toLowerCase();
        TriageResult r = new TriageResult();

        // Category = keyword group with the most hits
        Integer best = 0;
        r.category = 'General';
        for (String cat : CATEGORY_KEYWORDS.keySet()) {
            Integer hits = 0;
            for (String kw : CATEGORY_KEYWORDS.get(cat)) {
                if (text.contains(kw)) { hits++; r.matchedSignals.add(kw); }
            }
            if (hits > best) { best = hits; r.category = cat; }
        }

        // Urgency score 0-100
        Integer score = 10;
        for (String sig : URGENCY_SIGNALS.keySet()) {
            if (text.contains(sig)) { score += URGENCY_SIGNALS.get(sig); r.matchedSignals.add(sig); }
        }
        Integer negatives = 0;
        for (String w : NEGATIVE_WORDS) {
            if (text.contains(w)) { negatives++; }
        }
        r.sentiment = negatives >= 2 ? 'Negative' : (negatives == 1 ? 'Mixed' : 'Neutral');
        if (r.sentiment == 'Negative') { score += 15; }
        r.urgencyScore = Math.min(score, 100);

        r.priority = r.urgencyScore >= 70 ? 'Critical'
                   : r.urgencyScore >= 45 ? 'High'
                   : r.urgencyScore >= 25 ? 'Medium' : 'Low';
        r.targetQueue = CATEGORY_QUEUE.get(r.category);
        r.nextBestAction = nextBestAction(r);
        return r;
    }

    private String nextBestAction(TriageResult r) {
        if (r.priority == 'Critical') {
            return 'Escalate to ' + r.targetQueue + ' lead and call the customer within 1 hour.';
        }
        if (r.sentiment == 'Negative') {
            return 'Send an empathetic acknowledgement and offer a callback.';
        }
        switch on r.category {
            when 'Billing'   { return 'Review the last 3 invoices and share the related Knowledge article on billing disputes.'; }
            when 'Access'    { return 'Verify identity, then send a secure password/MFA reset link.'; }
            when 'Clinical'  { return 'Check prior-authorization status and route to care coordinator.'; }
            when 'Technical' { return 'Collect error details/screenshots and check the open-incident list.'; }
            when else        { return 'Respond with standard acknowledgement and suggested Knowledge articles.'; }
        }
    }
}
