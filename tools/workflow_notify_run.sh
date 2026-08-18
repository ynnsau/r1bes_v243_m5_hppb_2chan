#!/usr/bin/env bash
set -u

usage() {
  cat <<'EOF'
Usage:
  tools/workflow_notify_run.sh --kind <compile|regression|workflow|command> --name <name> -- <command> [args...]

Run one command and send best-effort start plus finish/error notifications.
The wrapped command's exit status is always preserved.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
notify_cmd=${WORKFLOW_NOTIFY_CMD:-"python3 $script_dir/send_workflow_ping.py"}
kind=command
name=

while [ "$#" -gt 0 ]; do
  case "$1" in
    --kind)
      kind=${2:-}
      shift 2
      ;;
    --name)
      name=${2:-}
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "workflow_notify_run.sh: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  echo "workflow_notify_run.sh: missing command after --" >&2
  usage >&2
  exit 2
fi

case "$kind" in
  compile|compilation|quartus)
    start_event=compile-start
    finish_event=compile-finish
    error_event=compile-error
    ;;
  regression|simulation|sim)
    start_event=regression-start
    finish_event=regression-finish
    error_event=test-error
    ;;
  workflow)
    start_event=workflow-start
    finish_event=workflow-finish
    error_event=tool-error
    ;;
  command|*)
    start_event=command-start
    finish_event=command-finish
    error_event=command-error
    ;;
esac

command_text="$*"
notify_name=${name:-$kind}

if [ "${WORKFLOW_NOTIFY:-1}" != "0" ]; then
  $notify_cmd \
    --event "$start_event" \
    --priority mid \
    --name "$notify_name" \
    --command "$command_text" \
    --body "Started $kind command." || true
fi

"$@"
rc=$?

if [ "${WORKFLOW_NOTIFY:-1}" != "0" ]; then
  if [ "$rc" -eq 0 ]; then
    $notify_cmd \
      --event "$finish_event" \
      --priority mid \
      --name "$notify_name" \
      --status PASS \
      --command "$command_text" \
      --body "Finished $kind command successfully." || true
  else
    $notify_cmd \
      --event "$error_event" \
      --priority high \
      --name "$notify_name" \
      --status "FAIL exit=$rc" \
      --command "$command_text" \
      --body "Stopped after $kind command failed with exit code $rc." || true
  fi
fi

exit "$rc"
