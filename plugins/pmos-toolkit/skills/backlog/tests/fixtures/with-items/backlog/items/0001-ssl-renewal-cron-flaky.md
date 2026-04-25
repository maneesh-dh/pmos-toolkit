---
id: 0001
title: SSL renewal cron is flaky
type: bug
status: ready
priority: should
score: 280
labels: [auth, ops]
created: 2026-04-20
updated: 2026-04-25
source: docs/.pmos/2026-04-15-auth-rewrite-plan.md
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---

## Context
The SSL renewal cron has failed silently three times in the last quarter, leading to expired certs in staging. The job logs nothing on failure and the alerting only fires on cert age, not job exit.

## Acceptance Criteria
- [ ] Cron job exits non-zero on failure
- [ ] Failures emit a structured log line consumed by the alerting pipeline
- [ ] A failing run pages oncall within 15 minutes

## Notes
Likely root cause: the wrapper script swallows certbot's exit code. Spotted while reading `/ops/cron/ssl-renew.sh`.
