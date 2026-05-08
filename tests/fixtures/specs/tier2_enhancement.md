---
tier: 2
type: enhancement
feature: csv-export-endpoint
date: 2026-05-08
status: Ready for Plan
requirements: ../requirements/tier2_csv_req.md
---

# CSV Export Endpoint — Spec {#csv-export-endpoint-spec}

## 1. Problem Statement {#problem-statement}

Customers ask for ad-hoc CSV exports of their orders for accounting workflows. The product currently only exposes JSON via the public API. Primary success metric: 30% of paying accounts use the endpoint at least once in the first quarter.

## 2. Goals {#goals}

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | Self-serve CSV export of orders | 30% adoption among paying accounts in Q1 |
| G2 | Streamable for large exports | p95 response start time < 500ms for 10k-row exports |

## 3. Non-Goals {#non-goals}

- We will not support arbitrary user-defined columns — fixed column set v1.
- No async / queued export — sync-only response v1.

## 4. Decision Log {#decision-log}

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | Streaming response (chunked transfer) | (a) buffer in memory, (b) stream | (b) handles 100k-row accounts without OOM |
| D2 | RFC 4180 quoting | (a) bare commas, (b) RFC 4180 | (b) is the format Excel/Sheets actually parse correctly |

## 5. User Journeys {#user-journeys}

1. User authenticates with their existing API key.
2. Issues `GET /api/v1/orders.csv?from=2026-01-01&to=2026-03-31`.
3. Streams CSV directly into their accounting tool.

## 6. Functional Requirements {#functional-requirements}

### 6.1 Endpoint contract {#endpoint-contract}

| ID | Requirement |
|----|-------------|
| FR-01 | `GET /api/v1/orders.csv` accepts optional `from` and `to` ISO-8601 date params; returns `text/csv; charset=utf-8` |
| FR-02 | Response body is RFC-4180-compliant CSV with header row: `order_id,created_at,total_cents,currency,status` |
| FR-03 | Response is chunked-transfer-encoded; first byte sent within 500ms of request receipt |

## 7. API Changes {#api-changes}

Request: `GET /api/v1/orders.csv?from=2026-01-01&to=2026-03-31` with `Authorization: Bearer <api-key>`.

Response (200): `Content-Type: text/csv; charset=utf-8`, `Transfer-Encoding: chunked`, body is the CSV stream.

Response (401): standard auth-error JSON envelope.

Response (400): standard validation-error JSON envelope when `from`/`to` are not parseable as ISO-8601 dates.

## 8. Frontend Design {#frontend-design}

No frontend in v1 — endpoint is API-only. UI surface is a follow-up.

## 9. Edge Cases {#edge-cases}

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | Empty result set | Date range matches no orders | Header row only, 200 OK |
| E2 | Reversed range | `from > to` | 400 with `error.code = "invalid_date_range"` |
| E3 | Excessive range | `>1 year` window | 400 with `error.code = "range_too_wide"` |

## 10. Testing & Verification Strategy {#testing-and-verification-strategy}

- Integration test: seed 1k orders, hit endpoint, parse CSV, assert row count + header.
- Streaming assertion: assert first byte arrives < 500ms via `curl -w '%{time_starttransfer}\n'`.
- RFC 4180 conformance: round-trip through `csv` module / `pandas.read_csv`.
- Verification command: `pytest tests/api/test_orders_csv.py -v`.
