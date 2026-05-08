# Non-Interactive Mode — Bats Test Suite

## Run all
bats plugins/pmos-toolkit/tests/non-interactive/*.bats

## Run one file
bats plugins/pmos-toolkit/tests/non-interactive/resolver.bats

## Verbose mode
bats --tap plugins/pmos-toolkit/tests/non-interactive/*.bats

## Prerequisites
- bats-core ≥ 1.5 (`brew install bats-core` on macOS)
- awk (POSIX or GNU)
- yq (`brew install yq`) — used by parser.bats

Helpers live in `test_helper.bash`. Fixtures in `fixtures/`.
