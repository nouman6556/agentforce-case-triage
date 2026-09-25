# Agentforce Case Triage & Next-Best-Action

An **Agentforce** service agent extension that triages support cases, scores urgency and sentiment, recommends a **next best action**, and drafts grounded customer replies with **Prompt Builder**.

> Portfolio / reference project. The Apex and LWC deploy to any org. The Agentforce topic and prompt templates are documented in `/agentforce` so you can configure them in an Agentforce-enabled org.

## Design idea

LLMs are good at language and bad at being consistent. So this project splits the work:

- **Deterministic Apex engine** (`CaseTriageEngine`) decides category, priority, sentiment, queue and next best action. It is fully unit-tested and auditable.
- **Agentforce action** (`TriageCaseAction`, an `@InvocableMethod`) exposes the engine to the agent, returning structured outputs plus a plain-language `agentMessage`.
- **Prompt Builder** templates use `CaseContextForPrompt` as grounding. That class gives the model a compact, PII-minimised view of the case, so it summarises and drafts replies without inventing facts.
- **LWC** (`caseTriageCard`) shows the same result to human agents on the Case page, with one-click "apply priority & routing".

```
User / Agent ──▶ Agentforce Topic "Case Management"
                    ├─ Action: Triage Case ─────▶ TriageCaseAction ─▶ CaseTriageEngine
                    ├─ Prompt: Case_Reply_Draft ─▶ CaseContextForPrompt (+ Knowledge RAG)
                    └─ Prompt: Case_Summary
Case page ──▶ LWC caseTriageCard ─▶ CaseTriageController ─▶ CaseTriageEngine
```

## Contents

| Path | Purpose |
|---|---|
| `classes/CaseTriageEngine.cls` | Weighted keyword classification, urgency score (0–100), sentiment, next best action. |
| `classes/TriageCaseAction.cls` | Invocable action for Agentforce and Flow. Uses `WITH USER_MODE` and `update as user`. |
| `classes/CaseRoutingService.cls` | Priority mapping and case-queue lookup. |
| `classes/CaseContextForPrompt.cls` | Grounding data for Prompt Builder templates. |
| `classes/CaseTriageController.cls` | LWC controller. |
| `classes/CaseTriageTest.cls` | Unit tests. |
| `lwc/caseTriageCard` | Case record page component. |
| `agentforce/` | Topic instructions, action mapping and prompt templates. |

## Setup

```bash
sf org create scratch -f config/project-scratch-def.json -a triage -d
sf project deploy start -d force-app
sf apex run test -l RunLocalTests -w 10 -c
```

1. Optional: create Case queues named `Billing_Support`, `Identity_Support`, `Care_Coordination`, `Tier_2_Technical` and `General_Support`.
2. Add **Agentforce Case Triage Card** to the Case Lightning record page.
3. In an Agentforce org: create the topic from `agentforce/agent-topic-case-management.md`, add the **Triage Case** Apex action, and create the prompt templates.

## Tech

Agentforce · Einstein Copilot Studio · Prompt Builder · Apex Invocable Actions · LWC · Service Cloud · SFDX · GitHub Actions
