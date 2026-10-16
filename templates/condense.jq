# Turns a Claude Code transcript (JSON lines) into a short plain-text record of
# the conversation for the curator. Keeps what the person and Claude said, a
# one-line note of each action, and any failures. Drops thinking, tool output
# and internal records, which are most of the file.
def clip($n): if length > $n then .[0:$n] + " [...]" else . end;
select(.type == "user" or .type == "assistant")
| select((.isMeta // false) | not)
| .type as $who
| (.message.content
   | if type == "string" then [{type: "text", text: .}] else . end)[]
| if .type == "text" and (.text | test("^\\s*$") | not) then
    (if $who == "user" then "PERSON: " else "CLAUDE: " end) + (.text | clip(4000))
  elif .type == "tool_use" then
    "ACTION: " + .name + " "
      + ((.input.file_path // .input.command // .input.pattern // .input.description // .input.url // "") | tostring | gsub("\n"; " ") | clip(200))
  elif .type == "tool_result" and (.is_error // false) then
    "FAILED: " + ((.content | if type == "string" then . else (map(.text? // "") | join(" ")) end) | gsub("\n"; " ") | clip(300))
  else empty end
