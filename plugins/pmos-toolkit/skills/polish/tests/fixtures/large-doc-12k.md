# Large document fixture (stub)

This file is a stub representing a 12,000-polishable-word document used to test chunking, stitch-back, and global-check correctness.

**To populate for actual test runs:** concatenate ~12,000 words of mixed-quality prose under H2 sections so the chunker has multiple H2 boundaries to split on. Suggested structure:

```
## Section 1 (~3000 words)
## Section 2 (~3000 words)
## Section 3 (~3000 words)
## Section 4 (~3000 words)
```

**Test assertions** (per `tests/expected.yaml`):

- Doc is chunked on H2 boundaries (4 chunks expected)
- Local checks (1, 5) fire and are detected per-chunk
- Global checks (2, 11) run on the WHOLE doc, not per-chunk
- Stitch-back produces a doc whose H2 boundary lines are byte-identical to the original
- Word-count delta lands in [-25%, -10%]
- Voice markers sampled ONCE from the whole doc (not per-chunk)
- Budget estimator accounts for chunking: `calls = 4 × per_chunk_local + global_check_count`

**Why this is a stub:** the expected detection behavior is fully specified by `tests/expected.yaml`. A real 12k-word fixture would be ~80KB of mostly-AI-slop prose; cheaper to generate at test time from a corpus + slop-injection script than to hand-author and version-control.

If implementing the real fixture, ensure each H2 section contains:
- At least one clutter word (check 1)
- At least 2 em-dashes (check 5 — exceeds technical preset's threshold of 1 per 200w with the right density)
- A passive-heavy paragraph (contributes to global check 2)
- Variable section length so check 11 (header inflation) fires on the shortest section
