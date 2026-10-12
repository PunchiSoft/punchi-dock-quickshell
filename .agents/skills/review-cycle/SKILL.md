---
name: review-cycle
description: Diagnose a reported dock regression using source observations, confirmed findings, scoped reproduction, and previous-attempt evidence.
---

# Bug review

Preserve the user's observations and recover related evidence before changing
code. Separate confirmed findings, hypotheses, product choices, and future work.

For substantial reviews, use ignored
`notes/reviews/review-YYYY-MM-DD-descriptor.md`, introducing an index and template
when first needed. Record reproduction, affected layer, plan, implementation,
validation, and attempts already tried. Keep personal evidence out of public docs.

Do not start with the full test suite. If diagnosis needs execution, justify a
focused reproduction. Correct the smallest responsible layer, then validate the
regression and relevant neighboring behavior. Never repeat a discarded solution
without identifying new evidence. Distinguish static analysis, component runtime,
real desktop checks, and explicit user confirmation before closing the review.
