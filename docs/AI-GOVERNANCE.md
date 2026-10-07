# KASIRA AI Governance

## AI role

AI is a read-oriented intelligence layer over canonical business data.

## Semantic layer

Expose business metrics rather than raw database tables:
- gross sales
- net sales
- COGS
- gross margin
- average basket
- repeat customer rate
- inventory turnover
- demand forecast
- outlet comparison

## Safe query architecture

```
User question
 -> Intent
 -> Semantic query
 -> Read-only execution
 -> Evidence/data
 -> Answer
```

## Actions

```
Recommendation
 -> Human approval
 -> Domain validation
 -> Command
 -> Audit
 -> Execution
```

AI must not autonomously:
- delete transactions
- void/refund without policy
- alter financial ledger
- manipulate stock ledger
- change privileged access

## Explainability

Where practical, AI answers should expose the metrics/period/outlet used to derive the recommendation.
