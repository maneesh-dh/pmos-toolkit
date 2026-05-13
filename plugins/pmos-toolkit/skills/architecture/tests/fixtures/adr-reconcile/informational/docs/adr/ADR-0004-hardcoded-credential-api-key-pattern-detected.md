# ADR-0004: hardcoded credential / API-key pattern detected

**Status:** Proposed
**Date:** 2026-05-13
**Triggered by:** /architecture audit (rule: U009, severity: block)

## Context

<1–3 paragraphs — what the rule is and where it fires. Replace this
placeholder with the human-authored context: why this rule exists in the
project's `principles.yaml`, what the offending code does, and what
risk it carries.>

## Decision

<1 paragraph — placeholder for human to fill in. The audit cannot make
the call for you: either the offending code is the intentional exception
(record the rationale + scope) or the rule wins (track the cleanup task).>

## Consequences

<1 paragraph — placeholder. Spell out what changes for future
contributors: is this a one-off exemption (add a row to `principles.yaml ::
exemptions:`?) or a precedent that should reshape the rule itself?>

## Suppresses

- rule: U009
  file: src/a.ts
  line: 2
