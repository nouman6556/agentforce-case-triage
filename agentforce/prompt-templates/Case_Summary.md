# Prompt Template: Case_Summary

**Type:** Record Summary (Case)

```
Summarise this case for a support agent taking over the conversation.
Return exactly:
1. One-line issue statement
2. What has been tried (bullets, from comments)
3. Customer sentiment and urgency
4. Recommended next action

{!$Apex:CaseContextForPrompt.Prompt}
```
