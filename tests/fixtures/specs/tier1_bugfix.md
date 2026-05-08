---
tier: 1
type: bugfix
feature: trim-username-whitespace
date: 2026-05-08
status: Ready for Plan
requirements: ../requirements/tier1_bugfix_req.md
---

# Trim Leading Whitespace in Usernames — Spec {#trim-leading-whitespace-in-usernames-spec}

## 1. Problem Statement {#problem-statement}

Users who paste their username from another app sometimes include a leading space, which causes profile-URL routing to 404 ("/u/ alice" misroutes). Reproduce: register a user with `" alice"` (leading space); the profile URL `/u/alice` returns 404.

## 2. Root Cause Analysis {#root-cause-analysis}

`UserService.create()` stores the input verbatim. `UserController.profile(username)` looks up the user by exact match. The whitespace survives both layers.

## 3. Fix Approach {#fix-approach}

Trim leading and trailing whitespace at `UserService.create()` and at the lookup layer in `UserController.profile()`. No backfill needed — broken users self-correct on next save.

## 4. Decision Log {#decision-log}

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | Trim at write AND read paths | (a) write only, (b) read only, (c) both | Both sides defends against legacy data without a migration |

## 5. Edge Cases {#edge-cases}

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | Inner whitespace | Username `"al ice"` submitted | Reject with validation error (already covered by FR-01) |

## 6. Testing Strategy {#testing-strategy}

Add a regression test: register `" alice"`, assert the stored username is `"alice"` and `/u/alice` returns 200. Run: `pytest tests/users/test_username_trim.py -v`.
