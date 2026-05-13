# ADR-0001: Informational suppression (test fixture)

**Status:** Accepted
**Date:** 2026-05-13
**Triggered by:** /architecture audit (rule: U009, severity: block)

## Context

Fixture-only ADR with a `## Suppresses` block but NO matching row in
`.pmos/architecture/principles.yaml`. Documents intent but does not actually
mute the finding (the principles.yaml row is what does that, per FR-65).

## Decision

Reconciliation must surface the finding AND emit an info-level note.

## Consequences

Audit reports the U009 finding for `src/a.ts` AND lists this ADR in
`exemptions.informational[]`.

## Suppresses

- rule: U009
  file: src/a.ts
  line: 2
