#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
load test_helper

@test "FR-01 case 1: flag --non-interactive alone" {
  run --separate-stderr resolve_mode --flag non-interactive --parent null --settings null
  [ "$status" -eq 0 ]
  [ "$output" = $'non-interactive\tflag' ]
}

@test "FR-01 case 2: flag --interactive alone" {
  run --separate-stderr resolve_mode --flag interactive --parent null --settings null
  [ "$output" = $'interactive\tflag' ]
}

@test "FR-01 case 3: settings non-interactive, no flag" {
  run --separate-stderr resolve_mode --flag null --parent null --settings non-interactive
  [ "$output" = $'non-interactive\tsettings:default_mode' ]
}

@test "FR-01 case 4: settings non-interactive, flag --interactive overrides" {
  run --separate-stderr resolve_mode --flag interactive --parent null --settings non-interactive
  [ "$output" = $'interactive\tflag' ]
}

@test "FR-01 case 5: settings invalid → warn + builtin default" {
  run --separate-stderr resolve_mode --flag null --parent null --settings garbage
  [ "$output" = $'interactive\tbuiltin-default' ]
  [[ "$stderr" == *"invalid default_mode value 'garbage'"* ]]
}

@test "FR-01 case 6: conflicting flags last wins (non-interactive)" {
  run --separate-stderr resolve_mode --flag non-interactive --parent null --settings null
  [ "$output" = $'non-interactive\tflag' ]
}

@test "FR-01 case 7: conflicting flags last wins (interactive)" {
  run --separate-stderr resolve_mode --flag interactive --parent null --settings null
  [ "$output" = $'interactive\tflag' ]
}

@test "FR-01 case 8: parent marker, no flag, no settings" {
  run --separate-stderr resolve_mode --flag null --parent non-interactive --settings null
  [ "$output" = $'non-interactive\tparent-skill-prompt' ]
}

@test "FR-01 case 9: parent marker AND flag → flag wins" {
  run --separate-stderr resolve_mode --flag interactive --parent non-interactive --settings null
  [ "$output" = $'interactive\tflag' ]
}
