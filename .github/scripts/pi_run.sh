#!/usr/bin/env bash
#
# Launch the `pi` harness for the ai-issue-autofix.yml pilot
# (plan: .omc/plans/pi-harness-migration.md, step 2/3).
#
# Like ai_pipeline.py, glm_agent.py and pi_wrapper.ts, this script must always
# run from a `main` checkout ($RUNNER_TEMP/trusted/.github/scripts/): it owns
# the flags that keep pi from reading anything the AI branch wrote. See
# AGENTS.md.
#
# Usage:
#   pi_run.sh --repo-root DIR --runner-temp DIR --message-file FILE \
#             [--commit-trailer TEXT] [--message-prefix TEXT]
#
# Exits 1 when the model never called submit, matching the `if
# result["aborted"]: sys.exit(1)` behaviour of the glm branch.
set -euo pipefail

# Pinned by .omc/research/pi-harness-spike.md (= pi 1.0.1, what `stable`
# resolved to on 2026-10-04). Never use a moving ref such as `stable`.
PI_REF="github:earendil-works/pi/a7229ddc21810d6245105978033b7df645ecc2f7"

# Backstop for the case where pi ignores the extension's shutdown() request
# after the turn/tool-call budget is spent. The budget itself lives in
# pi_wrapper.ts; this only stops a wedged job from burning the whole runner.
WALL_CLOCK_LIMIT="45m"

repo_root=""
runner_temp=""
message_file=""
commit_trailer=""
message_prefix=""

while [ $# -gt 0 ]; do
  case "$1" in
    --repo-root) repo_root="$2"; shift 2 ;;
    --runner-temp) runner_temp="$2"; shift 2 ;;
    --message-file) message_file="$2"; shift 2 ;;
    --commit-trailer) commit_trailer="$2"; shift 2 ;;
    --message-prefix) message_prefix="$2"; shift 2 ;;
    *) echo "::error::unknown argument: $1" >&2; exit 2 ;;
  esac
done

for name in repo_root runner_temp message_file; do
  if [ -z "${!name}" ]; then
    echo "::error::--${name//_/-} is required" >&2
    exit 2
  fi
done

scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pipeline="$scripts_dir/ai_pipeline.py"
extension="$scripts_dir/pi_wrapper.ts"
state_file="$runner_temp/pi_agent_state.json"
submit_marker="$runner_temp/pi_submitted"

# Fresh per run: written_paths must not carry over, and a marker left by an
# earlier run would turn an abort into a false success.
printf '[]' > "$state_file"
rm -f "$state_file.lock" "$submit_marker"

# Both constants come from the trusted python so the two engines cannot drift:
# the glm branch reads the same SYSTEM_PROMPT and MODEL objects.
read_all() { local text; text="$(cat "$1"; printf x)"; printf '%s' "${text%x}"; }

system_prompt="$(python3 -c '
import sys; sys.path.insert(0, sys.argv[1])
import ai_pipeline
sys.stdout.write(ai_pipeline.SYSTEM_PROMPT)
' "$scripts_dir")"
model="$(python3 -c '
import sys; sys.path.insert(0, sys.argv[1])
import glm_agent
sys.stdout.write(glm_agent.MODEL)
' "$scripts_dir")"
initial_message="$(read_all "$message_file")"

export PI_AGENT_PIPELINE="$pipeline"
export PI_AGENT_REPO_ROOT="$repo_root"
export PI_AGENT_STATE_FILE="$state_file"
export PI_AGENT_OUTPUT_DIR="$runner_temp"
export PI_AGENT_SUBMIT_MARKER="$submit_marker"
export PI_AGENT_COMMIT_TRAILER="$commit_trailer"
export PI_AGENT_MESSAGE_PREFIX="$message_prefix"
# Keep pi's own state under $RUNNER_TEMP rather than ~/.pi/agent.
export PI_CODING_AGENT_DIR="$runner_temp/pi-agent"

cd "$repo_root"

# Flag-by-flag rationale in .omc/research/pi-harness-spike.md:
#   -nc   this repo has a root AGENTS.md, and pi injects cwd-relative
#         AGENTS.md/CLAUDE.md into the system prompt regardless of project
#         trust — without this the AI branch rewrites its own next prompt (i)
#   -ne   no .pi/extensions/ discovery; an explicit -e path still loads (h)
#   -na   refuse project trust outright instead of relying on the "ask" default
#   -ns -np  no .pi/skills, .agents/skills, .pi/prompts
#   --no-session + --session-dir  .pi/settings.json's sessionDir is read before
#         trust resolves, so it has to be overridden explicitly (i)
#   --offline  no startup catalog fetch, for CI reproducibility
#   --no-builtin-tools  drops bash/write/edit at both the wire-declaration and
#         the dispatch layer, leaving only the six tools above (b)
#   --mode json  machine-readable turn/tool/agent events in the Actions log (a)
#   < /dev/null  pi otherwise blocks reading stdin in a non-TTY `run:` step (a)
set +e
timeout --signal=TERM "$WALL_CLOCK_LIMIT" \
  nix run "$PI_REF" -- \
    -nc -ne -na -ns -np \
    --no-session --session-dir "$runner_temp/pi-sessions" \
    --offline \
    --no-builtin-tools \
    -e "$extension" \
    --provider openrouter --model "$model" \
    --system-prompt "$system_prompt" \
    --mode json \
    -p -- "$initial_message" \
    < /dev/null
pi_status=$?
set -e

if [ ! -f "$submit_marker" ]; then
  echo "::error::pi のループが submit を呼ばずに終了しました (exit ${pi_status})。" >&2
  exit 1
fi

echo "pi run OK: $(cat "$submit_marker")"
