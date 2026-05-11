---
name: Dirty_Skill
description: Does a bunch of stuff with data. To use this skill: 1. point it at a file. 2. pick a mode with --foo or --bar. 3. wait for the output. 4. read the result. It might help sometimes if you want.
user-invocable: true
---

# Dirty Skill

A deliberately defective example skill used as the red fixture for
`tools/skill-eval-check.sh`. It has a name that is not lowercase-hyphenated and does
not match its directory, a description that embeds a numbered workflow, no
`argument-hint` even though the body parses `--foo` and `--bar`, an oversized body,
no Platform Adaptation section, no learnings-load line, no numbered Capture-Learnings
phase, a hard-coded absolute path, and an over-long reference file with no table of
contents. Every one of those is a planted `skill-eval.md` defect.

**Announce at start:** "Using Dirty_Skill."

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's
task-tracking tool. Mark each task in-progress when you start it and completed as
soon as it finishes.

## Phase 1: Parse arguments

Parse `--foo` and `--bar` from the argument string. `--foo` selects fast mode;
`--bar` selects batch mode. If neither is given, default to fast mode. If both are
given, the last one wins.

## Phase 2: Run the helper

Run the bundled helper at `/Users/someone/whatever/script.sh` against the input. (Yes,
this is a hard-coded absolute path — that is the planted `c-portable-paths` defect.)
See `reference/big.md` for the full option list.

## Phase 3: Emit the result

Print whatever the helper produced. Do not transform it further.

---

## Appendix: examples

The block below is intentionally repetitive padding so the body comfortably exceeds
800 lines — that is the planted `c-body-size` defect. Each "example" is the same
shape repeated; a real skill would never do this.

### Example 1

Input:

```
mode=fast
file=data-1.csv
rows=10
```

Command:

```
dirty-skill data-1.csv --foo
```

Output:

```
processed 10 rows in fast mode (run 1)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 2

Input:

```
mode=batch
file=data-2.csv
rows=20
```

Command:

```
dirty-skill data-2.csv --bar
```

Output:

```
processed 20 rows in batch mode (run 2)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 3

Input:

```
mode=fast
file=data-3.csv
rows=30
```

Command:

```
dirty-skill data-3.csv --foo
```

Output:

```
processed 30 rows in fast mode (run 3)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 4

Input:

```
mode=batch
file=data-4.csv
rows=40
```

Command:

```
dirty-skill data-4.csv --bar
```

Output:

```
processed 40 rows in batch mode (run 4)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 5

Input:

```
mode=fast
file=data-5.csv
rows=50
```

Command:

```
dirty-skill data-5.csv --foo
```

Output:

```
processed 50 rows in fast mode (run 5)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 6

Input:

```
mode=batch
file=data-6.csv
rows=60
```

Command:

```
dirty-skill data-6.csv --bar
```

Output:

```
processed 60 rows in batch mode (run 6)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 7

Input:

```
mode=fast
file=data-7.csv
rows=70
```

Command:

```
dirty-skill data-7.csv --foo
```

Output:

```
processed 70 rows in fast mode (run 7)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 8

Input:

```
mode=batch
file=data-8.csv
rows=80
```

Command:

```
dirty-skill data-8.csv --bar
```

Output:

```
processed 80 rows in batch mode (run 8)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 9

Input:

```
mode=fast
file=data-9.csv
rows=90
```

Command:

```
dirty-skill data-9.csv --foo
```

Output:

```
processed 90 rows in fast mode (run 9)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 10

Input:

```
mode=batch
file=data-10.csv
rows=100
```

Command:

```
dirty-skill data-10.csv --bar
```

Output:

```
processed 100 rows in batch mode (run 10)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 11

Input:

```
mode=fast
file=data-11.csv
rows=110
```

Command:

```
dirty-skill data-11.csv --foo
```

Output:

```
processed 110 rows in fast mode (run 11)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 12

Input:

```
mode=batch
file=data-12.csv
rows=120
```

Command:

```
dirty-skill data-12.csv --bar
```

Output:

```
processed 120 rows in batch mode (run 12)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 13

Input:

```
mode=fast
file=data-13.csv
rows=130
```

Command:

```
dirty-skill data-13.csv --foo
```

Output:

```
processed 130 rows in fast mode (run 13)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 14

Input:

```
mode=batch
file=data-14.csv
rows=140
```

Command:

```
dirty-skill data-14.csv --bar
```

Output:

```
processed 140 rows in batch mode (run 14)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 15

Input:

```
mode=fast
file=data-15.csv
rows=150
```

Command:

```
dirty-skill data-15.csv --foo
```

Output:

```
processed 150 rows in fast mode (run 15)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 16

Input:

```
mode=batch
file=data-16.csv
rows=160
```

Command:

```
dirty-skill data-16.csv --bar
```

Output:

```
processed 160 rows in batch mode (run 16)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 17

Input:

```
mode=fast
file=data-17.csv
rows=170
```

Command:

```
dirty-skill data-17.csv --foo
```

Output:

```
processed 170 rows in fast mode (run 17)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 18

Input:

```
mode=batch
file=data-18.csv
rows=180
```

Command:

```
dirty-skill data-18.csv --bar
```

Output:

```
processed 180 rows in batch mode (run 18)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 19

Input:

```
mode=fast
file=data-19.csv
rows=190
```

Command:

```
dirty-skill data-19.csv --foo
```

Output:

```
processed 190 rows in fast mode (run 19)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 20

Input:

```
mode=batch
file=data-20.csv
rows=200
```

Command:

```
dirty-skill data-20.csv --bar
```

Output:

```
processed 200 rows in batch mode (run 20)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 21

Input:

```
mode=fast
file=data-21.csv
rows=210
```

Command:

```
dirty-skill data-21.csv --foo
```

Output:

```
processed 210 rows in fast mode (run 21)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 22

Input:

```
mode=batch
file=data-22.csv
rows=220
```

Command:

```
dirty-skill data-22.csv --bar
```

Output:

```
processed 220 rows in batch mode (run 22)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 23

Input:

```
mode=fast
file=data-23.csv
rows=230
```

Command:

```
dirty-skill data-23.csv --foo
```

Output:

```
processed 230 rows in fast mode (run 23)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 24

Input:

```
mode=batch
file=data-24.csv
rows=240
```

Command:

```
dirty-skill data-24.csv --bar
```

Output:

```
processed 240 rows in batch mode (run 24)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 25

Input:

```
mode=fast
file=data-25.csv
rows=250
```

Command:

```
dirty-skill data-25.csv --foo
```

Output:

```
processed 250 rows in fast mode (run 25)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 26

Input:

```
mode=batch
file=data-26.csv
rows=260
```

Command:

```
dirty-skill data-26.csv --bar
```

Output:

```
processed 260 rows in batch mode (run 26)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 27

Input:

```
mode=fast
file=data-27.csv
rows=270
```

Command:

```
dirty-skill data-27.csv --foo
```

Output:

```
processed 270 rows in fast mode (run 27)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 28

Input:

```
mode=batch
file=data-28.csv
rows=280
```

Command:

```
dirty-skill data-28.csv --bar
```

Output:

```
processed 280 rows in batch mode (run 28)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 29

Input:

```
mode=fast
file=data-29.csv
rows=290
```

Command:

```
dirty-skill data-29.csv --foo
```

Output:

```
processed 290 rows in fast mode (run 29)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 30

Input:

```
mode=batch
file=data-30.csv
rows=300
```

Command:

```
dirty-skill data-30.csv --bar
```

Output:

```
processed 300 rows in batch mode (run 30)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 31

Input:

```
mode=fast
file=data-31.csv
rows=310
```

Command:

```
dirty-skill data-31.csv --foo
```

Output:

```
processed 310 rows in fast mode (run 31)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 32

Input:

```
mode=batch
file=data-32.csv
rows=320
```

Command:

```
dirty-skill data-32.csv --bar
```

Output:

```
processed 320 rows in batch mode (run 32)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 33

Input:

```
mode=fast
file=data-33.csv
rows=330
```

Command:

```
dirty-skill data-33.csv --foo
```

Output:

```
processed 330 rows in fast mode (run 33)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 34

Input:

```
mode=batch
file=data-34.csv
rows=340
```

Command:

```
dirty-skill data-34.csv --bar
```

Output:

```
processed 340 rows in batch mode (run 34)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 35

Input:

```
mode=fast
file=data-35.csv
rows=350
```

Command:

```
dirty-skill data-35.csv --foo
```

Output:

```
processed 350 rows in fast mode (run 35)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 36

Input:

```
mode=batch
file=data-36.csv
rows=360
```

Command:

```
dirty-skill data-36.csv --bar
```

Output:

```
processed 360 rows in batch mode (run 36)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 37

Input:

```
mode=fast
file=data-37.csv
rows=370
```

Command:

```
dirty-skill data-37.csv --foo
```

Output:

```
processed 370 rows in fast mode (run 37)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 38

Input:

```
mode=batch
file=data-38.csv
rows=380
```

Command:

```
dirty-skill data-38.csv --bar
```

Output:

```
processed 380 rows in batch mode (run 38)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 39

Input:

```
mode=fast
file=data-39.csv
rows=390
```

Command:

```
dirty-skill data-39.csv --foo
```

Output:

```
processed 390 rows in fast mode (run 39)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

### Example 40

Input:

```
mode=batch
file=data-40.csv
rows=400
```

Command:

```
dirty-skill data-40.csv --bar
```

Output:

```
processed 400 rows in batch mode (run 40)
status: ok
```

Notes: identical in structure to every other example here — pure line-count padding,
the planted `c-body-size` defect. Not a pattern worth following.

## End of appendix

That is the entire (deliberately bloated) body.
