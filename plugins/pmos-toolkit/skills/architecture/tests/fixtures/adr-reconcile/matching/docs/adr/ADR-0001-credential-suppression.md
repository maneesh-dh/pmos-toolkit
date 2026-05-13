# ADR-0001: Hardcoded credential suppression (test fixture)

**Status:** Accepted
**Date:** 2026-05-13
**Triggered by:** /architecture audit (rule: U009, severity: block)

## Context

Fixture-only ADR pre-seeded for T15 reconciliation test. Pairs with the
matching exemption row in `.pmos/architecture/principles.yaml`.

## Decision

Accept the hardcoded AWS-key string in `src/a.ts` as an intentional fixture
sample; reconciliation should silently suppress the U009 finding.

## Consequences

Audit reports zero findings for this fixture when the matching exemption is
honoured. Drift here means reconciliation regressed.

## Suppresses

- rule: U009
  file: src/a.ts
  line: 2
