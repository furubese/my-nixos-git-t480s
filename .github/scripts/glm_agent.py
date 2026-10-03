#!/usr/bin/env python3
"""Shared agent loop for the AI Nix-editing pipeline.

Used by ai-issue-handler.yml, ai-issue-autofix.yml and ai-issue-feedback.yml.
Like ai_pipeline.py, this file must always be checked out from `main` (never
from an AI-controlled branch): it drives the tool sandbox, so a branch that
could rewrite it could also widen its own permissions. See AGENTS.md.

The model drives a multi-turn tool-calling loop (OpenRouter / z-ai/glm-5.3)
with six tools: list_dir, read_file, write_file, delete_file, run_command and
submit. Every call — accepted or denied — is logged with its arguments so the
Actions log distinguishes "tried and was refused" from "never tried".

The sandbox those tools run in (AgentSession, the allow-lists, SYSTEM_PROMPT)
lives in ai_pipeline.py and is re-exported below, so this loop and the pi
harness's `agent-*` CLI subcommands share one implementation. The import is
one-way: ai_pipeline.py must never import this module.
"""
import json
import os
import urllib.request

from ai_pipeline import (  # noqa: F401  (re-exported for existing callers)
    ALLOWED_COMMANDS,
    COMMAND_TIMEOUTS,
    DENIED_FLAGS,
    DENIED_NIX_SUBCOMMANDS,
    MAX_OUTPUT_CHARS,
    MAX_READ_BYTES,
    SYSTEM_PROMPT,
    AgentSession,
    ToolDenied,
    _ALWAYS_DENIED_ENV,
    _SECRET_ENV_RE,
    _Submitted,
    _run_env,
    _truncate,
    _write_outputs,
)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "z-ai/glm-5.3"
REQUEST_TIMEOUT = 120

TOOL_DEFINITIONS = [
    {
        "type": "function",
        "function": {
            "name": "list_dir",
            "description": "リポジトリ内のディレクトリの内容を一覧表示する。",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "リポジトリルートからの相対パス（例: home/ai）。",
                    }
                },
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "read_file",
            "description": "リポジトリ内のファイルを読む（.git/** と secrets/** は不可）。",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "リポジトリルートからの相対パス。",
                    }
                },
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "write_file",
            "description": "許可パスにファイルを書き込む（既存なら全体を置き換える）。",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "modules/ai, home/ai, tests/ai 直下の許可パス。",
                    },
                    "content": {
                        "type": "string",
                        "description": "ファイルの完全な内容。",
                    },
                },
                "required": ["path", "content"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "delete_file",
            "description": "許可パスのファイルを削除する（追跡済みか、今回書いたファイルのみ）。",
            "parameters": {
                "type": "object",
                "properties": {
                    "path": {
                        "type": "string",
                        "description": "modules/ai, home/ai, tests/ai 直下の許可パス。",
                    }
                },
                "required": ["path"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "run_command",
            "description": "検証コマンドを実行する（nix / niri / nix-instantiate のみ）。",
            "parameters": {
                "type": "object",
                "properties": {
                    "argv": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "argv配列（例: [\"niri\", \"validate\", \"-c\", \"home/ai/niri.kdl\"]）。",
                    }
                },
                "required": ["argv"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "submit",
            "description": "作業完了を宣言してループを終了する。",
            "parameters": {
                "type": "object",
                "properties": {
                    "title": {
                        "type": "string",
                        "description": "変更内容を要約したPRタイトル（日本語可、60文字程度）。",
                    },
                    "summary": {
                        "type": "string",
                        "description": "何をどう変えたかの要約。箇条書き推奨。",
                    },
                },
                "required": ["title", "summary"],
            },
        },
    },
]


def _openrouter_request(payload):
    api_key = os.environ["OPENROUTER_API_KEY"]
    request = urllib.request.Request(
        OPENROUTER_URL,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=REQUEST_TIMEOUT) as response:
        return json.load(response)


def run_agent_loop(
    initial_message,
    commit_trailer=None,
    max_turns=15,
    max_tool_calls=40,
    *,
    repo_root=None,
    output_dir=None,
    request_fn=None,
):
    """Run the tool-calling loop until submit(), a limit, or a fatal error.

    `initial_message` must already have been through ai_pipeline.sanitize_text()
    by the caller: issue bodies, PR comments and CI logs are untrusted input and
    this loop can write, delete and execute.

    On submit, writes pr_title.txt / pr_summary.txt / commit_msg.txt into
    `output_dir` (default $RUNNER_TEMP). `commit_trailer` is appended to
    commit_msg.txt after a blank line — autofix passes "AI-Autofix-Attempt: true",
    feedback deliberately passes None so its commits reset the attempt streak.

    Returns {"title", "summary", "aborted", "abort_reason"}.
    """
    session = AgentSession(repo_root)
    output_dir = output_dir or os.environ["RUNNER_TEMP"]
    request_fn = request_fn or _openrouter_request

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": initial_message},
    ]
    trace = []
    tool_calls_used = 0

    def abort(reason):
        attempted = "; ".join(trace[-20:]) or "(ツール呼び出しなし)"
        print(f"::error::{reason} 試行内容: {attempted}")
        return {"title": "", "summary": "", "aborted": True, "abort_reason": reason}

    for turn in range(1, max_turns + 1):
        print(f"--- turn {turn}/{max_turns} (tool calls used: {tool_calls_used}/{max_tool_calls})")
        response = request_fn(
            {
                "model": MODEL,
                "messages": messages,
                "tools": TOOL_DEFINITIONS,
                "temperature": 0,
            }
        )
        try:
            message = response["choices"][0]["message"]
        except (KeyError, IndexError, TypeError):
            return abort(f"モデルの応答が解釈できません: {response!r}")

        tool_calls = message.get("tool_calls") or []
        messages.append(
            {
                "role": "assistant",
                "content": message.get("content") or "",
                **({"tool_calls": tool_calls} if tool_calls else {}),
            }
        )
        if message.get("content"):
            print(f"model: {_truncate(message['content'], 2000)}")

        if not tool_calls:
            messages.append(
                {
                    "role": "user",
                    "content": "ツールを呼び出して作業を進めてください。"
                    "作業が完了している場合は submit(title, summary) を呼んでください。",
                }
            )
            continue

        for call in tool_calls:
            if tool_calls_used >= max_tool_calls:
                return abort(f"ツール呼び出し上限({max_tool_calls})に到達したため中断しました。")
            tool_calls_used += 1

            name = call.get("function", {}).get("name", "")
            raw_arguments = call.get("function", {}).get("arguments") or "{}"
            try:
                arguments = json.loads(raw_arguments) if isinstance(raw_arguments, str) else raw_arguments
            except json.JSONDecodeError:
                arguments = None
            if not isinstance(arguments, dict):
                result = f"DENIED: arguments are not a JSON object: {raw_arguments!r}"
                print(f"tool {name} DENIED (bad arguments)")
                trace.append(f"{name}(invalid-args) -> DENIED")
            else:
                printable = {
                    key: (value if key != "content" else f"<{len(str(value))} bytes>")
                    for key, value in arguments.items()
                }
                try:
                    result = session.dispatch(name, arguments)
                    print(f"tool {name}({json.dumps(printable, ensure_ascii=False)}) -> OK")
                    trace.append(f"{name}({json.dumps(printable, ensure_ascii=False)}) -> OK")
                except ToolDenied as denied:
                    result = f"DENIED: {denied}"
                    print(f"tool {name}({json.dumps(printable, ensure_ascii=False)}) -> DENIED: {denied}")
                    trace.append(f"{name}({json.dumps(printable, ensure_ascii=False)}) -> DENIED")
                except _Submitted as submitted:
                    print(f"tool submit(title={submitted.title!r}) -> OK")
                    _write_outputs(submitted.title, submitted.summary, commit_trailer, output_dir)
                    return {
                        "title": submitted.title,
                        "summary": submitted.summary,
                        "aborted": False,
                        "abort_reason": None,
                    }
                except OSError as error:
                    result = f"ERROR: {error}"
                    print(f"tool {name} -> ERROR: {error}")
                    trace.append(f"{name} -> ERROR")

            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": call.get("id", ""),
                    "content": _truncate(str(result)),
                }
            )

    return abort(f"応答ターン上限({max_turns})に到達し submit が呼ばれませんでした。")
