#!/usr/bin/env bats

load helpers

# Write a fake saved conversation: $1 folder, $2 id, $3 date, $4 cwd, $5 title,
# then pairs of (role, text).
fake_conversation() {
  local dir="$SCRIBE_TRANSCRIPTS/$1" id="$2" date="$3" cwd="$4" title="$5"
  shift 5
  mkdir -p "$dir"
  python3 - "$dir/$id.jsonl" "$date" "$cwd" "$title" "$@" <<'PY'
import json, sys
path, date, cwd, title, *pairs = sys.argv[1:]
with open(path, "w") as f:
    for i in range(0, len(pairs), 2):
        role, text = pairs[i], pairs[i + 1]
        content = text if role == "user" else [{"type": "text", "text": text}]
        f.write(json.dumps({"type": role, "timestamp": f"{date}T10:0{i // 2}:00Z", "cwd": cwd,
                            "message": {"role": role, "content": content}}) + "\n")
    f.write(json.dumps({"type": "ai-title", "aiTitle": title}) + "\n")
PY
}

setup() {
  setup_isolated_env
  export SCRIBE_TRANSCRIPTS="$TEST_HOME/transcripts"
  P="$HOME/projects"
  mkdir -p "$P/garden" "$P/patio"
  fake_conversation home a1 2026-09-01 "$P/patio" "Patio drainage" \
    user "Rain keeps pooling against the back wall" \
    assistant "We could lay a French drain with perforated pipe to the soakaway."
  fake_conversation home b2 2026-10-10 "$P/garden" "Garden soil" \
    user "The soil is heavy clay and drains badly" \
    assistant "Raised beds would keep roots out of the wet clay."
  fake_conversation home c3 2026-10-12 "$HOME" "Helper run" \
    user "You are the curator of the project journal for garden." \
    assistant "Done. Drains badly noted."
}
teardown() { teardown_isolated_env; }

@test "recall: finds the conversation with every word, with date, title and project" {
  run "$SCRIBE_BIN" recall "french drain"
  [ "$status" -eq 0 ]
  [[ "$output" == *'## 1 Sep 2026 · "Patio drainage" · patio · a1'* ]]
  [[ "$output" == *"CLAUDE: We could lay a French drain"* ]]
  [[ "$output" != *"Garden soil"* ]]
}

@test "recall: skips background helper conversations" {
  run "$SCRIBE_BIN" recall "drains badly"
  [[ "$output" == *"Garden soil"* ]]
  [[ "$output" != *"Helper run"* ]]
}

@test "recall: words can be in different messages of the same conversation" {
  run "$SCRIBE_BIN" recall clay roots
  [[ "$output" == *"Garden soil"* ]]
}

@test "recall: --project limits the search" {
  run "$SCRIBE_BIN" recall drain --project garden
  [[ "$output" == *"Garden soil"* ]]
  [[ "$output" != *"Patio drainage"* ]]
}

@test "recall: leaves out the current session" {
  run "$SCRIBE_BIN" recall "french drain" --session a1
  [[ "$output" == *"No past conversation mentions"* ]]
}

@test "recall: says when nothing matches" {
  run "$SCRIBE_BIN" recall zebra
  [[ "$output" == *"No past conversation mentions all of: zebra"* ]]
}

@test "recall: --show prints the conversation around the words" {
  run "$SCRIBE_BIN" recall --show b2 clay
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Garden soil (10 Oct 2026 to 10 Oct 2026)"* ]]
  [[ "$output" == *"PERSON: The soil is heavy clay"* ]]
}

@test "recall: only re-reads conversations that changed" {
  "$SCRIBE_BIN" recall drain >/dev/null
  before=$(stat -f %m "$HOME/.scribe/recall/a1.txt" 2>/dev/null || stat -c %Y "$HOME/.scribe/recall/a1.txt")
  sleep 1
  "$SCRIBE_BIN" recall drain >/dev/null
  after=$(stat -f %m "$HOME/.scribe/recall/a1.txt" 2>/dev/null || stat -c %Y "$HOME/.scribe/recall/a1.txt")
  [ "$before" = "$after" ]
  sleep 1
  touch "$SCRIBE_TRANSCRIPTS/home/a1.jsonl"
  "$SCRIBE_BIN" recall drain >/dev/null
  newer=$(stat -f %m "$HOME/.scribe/recall/a1.txt" 2>/dev/null || stat -c %Y "$HOME/.scribe/recall/a1.txt")
  [ "$newer" != "$before" ]
}

@test "recall: a word like * is searched for, not expanded" {
  run "$SCRIBE_BIN" recall "**"
  [ "$status" -eq 0 ]
}

@test "recall: the session end adds the finished conversation" {
  install_fake_claude
  "$SCRIBE_BIN" new garden2 >/dev/null
  T="$SCRIBE_REPO/test/fixtures/session.jsonl"
  printf '{"cwd":"%s","session_id":"sess","transcript_path":"%s"}' "$P/garden2" "$T" | "$SCRIBE_BIN" hook session-end
  wait_for_file "$HOME/.scribe/recall/session.txt"
  grep -q "magic links" "$HOME/.scribe/recall/session.txt"
}
