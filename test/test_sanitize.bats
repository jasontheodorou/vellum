#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "sanitize: simple name passes through" {
  run "$VELLUM_BIN" __sanitize "my-cool-app"
  [ "$status" -eq 0 ]
  [ "$output" = "my-cool-app" ]
}

@test "sanitize: spaces become underscores" {
  run "$VELLUM_BIN" __sanitize "My Cool App"
  [ "$output" = "My_Cool_App" ]
}

@test "sanitize: special characters become underscores" {
  run "$VELLUM_BIN" __sanitize "weird/path:name"
  [ "$output" = "weird_path_name" ]
}

@test "sanitize: collapses runs of underscores" {
  run "$VELLUM_BIN" __sanitize "foo   bar"
  [ "$output" = "foo_bar" ]
}

@test "sanitize: preserves dots and hyphens" {
  run "$VELLUM_BIN" __sanitize "v1.0-beta"
  [ "$output" = "v1.0-beta" ]
}
