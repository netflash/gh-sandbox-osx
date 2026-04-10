#!/usr/bin/env bats

setup() {
  TEST_DIR=$(mktemp -d)
  SCRIPT="$BATS_TEST_DIRNAME/../import-token"

  # Control where the sandbox hosts file goes via env var override
  mkdir -p "$TEST_DIR/env/.config/gh"
  SANDBOX_HOSTS="$TEST_DIR/env/.config/gh/hosts.yml"
  export SANDBOX_HOSTS_OVERRIDE="$SANDBOX_HOSTS"

  # Override HOME so SYSTEM_HOSTS = TEST_DIR/.config/gh/hosts.yml
  export HOME="$TEST_DIR"
  mkdir -p "$HOME/.config/gh"
  SYSTEM_HOSTS="$HOME/.config/gh/hosts.yml"

  # Prepend fake security binary so it shadows the real macOS one
  export PATH="$BATS_TEST_DIRNAME/bin:$PATH"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# Username resolution
# ---------------------------------------------------------------------------

@test "username from CLI arg" {
  run "$SCRIPT" alice
  [ "$status" -eq 0 ]
  [[ "$output" == *"Importing token for user: alice"* ]]
}

@test "username from sandbox hosts.yml user: key" {
  cp "$BATS_TEST_DIRNAME/fixtures/hosts-single.yml" "$SANDBOX_HOSTS"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Importing token for user: alice"* ]]
}

@test "single user in system hosts.yml is auto-selected" {
  cp "$BATS_TEST_DIRNAME/fixtures/hosts-single.yml" "$SYSTEM_HOSTS"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Importing token for user: alice"* ]]
}

@test "multiple users in system hosts.yml: user picks via stdin" {
  cp "$BATS_TEST_DIRNAME/fixtures/hosts-multi.yml" "$SYSTEM_HOSTS"
  run bash -c "echo '1' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Importing token for user: alice"* ]]
}

@test "no username source exits with error" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not determine GitHub username"* ]]
}

# ---------------------------------------------------------------------------
# Token extraction and decoding
# ---------------------------------------------------------------------------

@test "go-keyring-base64 token is decoded correctly" {
  run "$SCRIPT" alice
  [ "$status" -eq 0 ]
  grep -q "oauth_token: ghp_TESTTOKEN" "$SANDBOX_HOSTS"
}

@test "raw token is passed through as-is" {
  run "$SCRIPT" multi-user
  [ "$status" -eq 0 ]
  grep -q "oauth_token: gho_RAWTOKEN" "$SANDBOX_HOSTS"
}

@test "missing keychain entry exits with error" {
  run "$SCRIPT" unknown-user
  [ "$status" -eq 1 ]
  [[ "$output" == *"no keychain entry found"* ]]
}

@test "invalid token format exits with error" {
  run "$SCRIPT" badtoken
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not look like a gh token"* ]]
}

# ---------------------------------------------------------------------------
# hosts.yml writing
# ---------------------------------------------------------------------------

@test "creates sandbox hosts.yml when it does not exist" {
  run "$SCRIPT" alice
  [ "$status" -eq 0 ]
  [ -f "$SANDBOX_HOSTS" ]
  grep -q "oauth_token: ghp_TESTTOKEN" "$SANDBOX_HOSTS"
  grep -q "user: alice" "$SANDBOX_HOSTS"
  grep -q "git_protocol: https" "$SANDBOX_HOSTS"
}

@test "inserts token into existing hosts.yml with no token" {
  cp "$BATS_TEST_DIRNAME/fixtures/hosts-single.yml" "$SANDBOX_HOSTS"
  run "$SCRIPT" alice
  [ "$status" -eq 0 ]
  grep -q "oauth_token: ghp_TESTTOKEN" "$SANDBOX_HOSTS"
}

@test "replaces stale token in existing hosts.yml" {
  cp "$BATS_TEST_DIRNAME/fixtures/hosts-with-token.yml" "$SANDBOX_HOSTS"
  run "$SCRIPT" alice
  [ "$status" -eq 0 ]
  grep -q "oauth_token: ghp_TESTTOKEN" "$SANDBOX_HOSTS"
  run grep "ghp_STALETOKEN" "$SANDBOX_HOSTS"
  [ "$status" -ne 0 ]
}
