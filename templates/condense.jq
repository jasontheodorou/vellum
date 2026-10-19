# Turns a Claude Code transcript (JSON lines) into a short plain-text record of
# the conversation for the curator. Keeps what the person and Claude said, a
# one-line note of each action, and any failures. Drops thinking, tool output
# and internal records, which are most of the file.
#
# Run it with -R, so each line arrives as text: a line that is not JSON (such
# as a half-written last line) is skipped instead of stopping the whole run.
# It also works on already-parsed input. Anything that is not the expected
# shape is skipped, the same as the Python copy in lib/journal.sh.
def clip($n): if length > $n then .[0:$n] + " [...]" else . end;
def text_of: if type == "string" then . elif type == "null" then "" else tostring end;
(if type == "string" then (fromjson? // empty) else . end)
| select(type == "object")
| select(.type == "user" or .type == "assistant")
| select((.isMeta // false) | not)
| .type as $who
| (if (.message | type) == "object" then .message.content else null end)
| (if type == "string" then [{type: "text", text: .}] elif type == "array" then . else [] end)[]
| (if type == "string" then {type: "text", text: .} elif type == "object" then . else empty end)
| if .type == "text" and (.text | type) == "string" and (.text | test("^\\s*$") | not) then
    (if $who == "user" then "PERSON: " else "CLAUDE: " end) + (.text | clip(4000))
  elif .type == "tool_use" then
    "ACTION: " + (.name | text_of) + " "
      + ((if (.input | type) == "object" then (.input.file_path // .input.command // .input.pattern // .input.description // .input.url // "") else "" end) | text_of | gsub("\n"; " ") | clip(200))
  elif .type == "tool_result" and (.is_error // false) then
    "FAILED: " + ((.content | if type == "string" then . elif type == "array" then (map(if type == "object" then (.text // "" | text_of) else "" end) | join(" ")) else text_of end) | gsub("\n"; " ") | clip(300))
  else empty end
