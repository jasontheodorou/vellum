#!/usr/bin/env bats

load helpers

# Write a fake saved conversation: $1 folder, $2 id, $3 date, $4 cwd, $5 title,
# then pairs of (role, text).
fake_conversation() {
  local dir="$VELLUM_TRANSCRIPTS/$1" id="$2" date="$3" cwd="$4" title="$5"
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
  export VELLUM_TRANSCRIPTS="$TEST_HOME/transcripts"
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
  run "$VELLUM_BIN" recall "french drain"
  [ "$status" -eq 0 ]
  [[ "$output" == *'## 1 Sep 2026 · "Patio drainage" · patio · a1'* ]] || false
  [[ "$output" == *"CLAUDE: We could lay a French drain"* ]] || false
  [[ "$output" != *"Garden soil"* ]] || false
}

@test "recall: skips background helper conversations" {
  run "$VELLUM_BIN" recall "drains badly"
  [[ "$output" == *"Garden soil"* ]] || false
  [[ "$output" != *"Helper run"* ]] || false
}

@test "recall: words can be in different messages of the same conversation" {
  run "$VELLUM_BIN" recall clay roots
  [[ "$output" == *"Garden soil"* ]] || false
}

@test "recall: --project limits the search" {
  run "$VELLUM_BIN" recall drain --project garden
  [[ "$output" == *"Garden soil"* ]] || false
  [[ "$output" != *"Patio drainage"* ]] || false
}

@test "recall: leaves out the current session" {
  run "$VELLUM_BIN" recall "french drain" --session a1
  [[ "$output" == *"No past conversation mentions"* ]] || false
}

@test "recall: says when nothing matches" {
  run "$VELLUM_BIN" recall zebra
  [[ "$output" == *"No past conversation mentions all of: zebra"* ]] || false
}

@test "recall: --show prints the conversation around the words" {
  run "$VELLUM_BIN" recall --show b2 clay
  [ "$status" -eq 0 ]
  [[ "$output" == *"# Garden soil (10 Oct 2026 to 10 Oct 2026)"* ]] || false
  [[ "$output" == *"PERSON: The soil is heavy clay"* ]] || false
}

@test "recall: only re-reads conversations that changed" {
  "$VELLUM_BIN" recall drain >/dev/null
  before=$(stat -f %m "$HOME/.vellum/recall/a1.txt")
  sleep 1
  "$VELLUM_BIN" recall drain >/dev/null
  after=$(stat -f %m "$HOME/.vellum/recall/a1.txt")
  [ "$before" = "$after" ]
  sleep 1
  touch "$VELLUM_TRANSCRIPTS/home/a1.jsonl"
  "$VELLUM_BIN" recall drain >/dev/null
  newer=$(stat -f %m "$HOME/.vellum/recall/a1.txt")
  [ "$newer" != "$before" ]
}

@test "recall: a word like * is searched for, not expanded" {
  run "$VELLUM_BIN" recall "**"
  [ "$status" -eq 0 ]
}

@test "recall: the session end adds the finished conversation" {
  install_fake_claude
  "$VELLUM_BIN" new garden2 >/dev/null
  T="$VELLUM_REPO/test/fixtures/session.jsonl"
  printf '{"cwd":"%s","session_id":"sess","transcript_path":"%s"}' "$P/garden2" "$T" | "$VELLUM_BIN" hook session-end
  wait_for_file "$HOME/.vellum/recall/session.txt"
  grep -q "magic links" "$HOME/.vellum/recall/session.txt"
}

@test "recall: a word finds longer words that start with it, not words that contain it" {
  run "$VELLUM_BIN" recall drain --project garden
  [[ "$output" == *"Garden soil"* ]] || false
  fake_conversation home d4 2026-10-13 "$P/garden" "Embeds" user "The page embeds a video" assistant "Fine."
  run "$VELLUM_BIN" recall beds
  [[ "$output" != *"Embeds"* ]] || false
}
