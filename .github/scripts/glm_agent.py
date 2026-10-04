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
import re
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
    sanitize_text,
)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
MODEL = "z-ai/glm-5.3"
REQUEST_TIMEOUT = 120

# 複雑性分類専用の軽量モデル。本番のエージェントループ（MODEL）とは別物で、
# 「simple か complex の一語」だけを返させる。
CLASSIFIER_MODEL = "z-ai/glm-5.3-flash"

# verdictの正規化で文字列の**両端からのみ**除去する文字。`?` と `!` は意図的に
# 含めない——`"complex?"` のようなヘッジ応答を確信ありの完全一致に変えてしまい、
# 「complexと確定できなければglmへfail-safe」という原則に反するため。
_VERDICT_STRIP_CHARS = ".`\"'*。 "

# 分類器が返しうる既知の応答。どちらとも一致しない応答（空応答・未知の文字列・
# 切り詰め）は呼び出し元が `::warning::` で可視化する。
_RECOGNIZED_VERDICTS = ("complex", "simple")

# issue本文中の「バッククォートで囲まれたファイルパス」を拾う。このリポジトリのissueは
# `modules/ai/bottle.nix` のようにパスを必ずバッククォートで囲んで書く（issue #102の
# 本文がその実例）。拡張子（`\.\w+`）を必須にしているのは、`grep -rn` のようなコマンド片や
# `simple` のような単語を拾わないため。文字クラスを `[\w./-]` に閉じていることは
# プロンプト注入対策も兼ねる——抽出結果は分類プロンプトへそのまま埋め込まれるが、
# 改行もバッククォートもこのクラスを通過できない。
_PATH_MENTION_RE = re.compile(r"`([\w./-]+\.\w+)`")


def extract_path_mentions(text):
    """Return the distinct backtick-quoted file paths mentioned in `text`.

    Order is first-appearance order, so an injected hint reads in the same order
    as the issue body. Used only to give the classifier a countable fact; it is
    never used to decide what the agent may touch (that is the allow-list's job).
    """
    found = []
    for path in _PATH_MENTION_RE.findall(text or ""):
        if path not in found:
            found.append(path)
    return found


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


def resolve_engine(configured, title, body, labels=(), *, request_fn=None):
    """Pick the engine (glm or pi) that handles one issue.

    Precedence, highest first:

    1. `configured in ("glm", "pi")` — an explicit vars.AI_HANDLER_ENGINE wins
       unconditionally and makes **zero** network calls. This path must stay
       behaviourally identical to the pre-auto-selection handler.
    2. a `complex-request` / `simple-request` label on the issue. A label
       *replaces* the classification call (it never overrides 1.). Both labels
       at once resolves as `simple-request`: erring toward the bounded engine is
       the safe direction.
    3. the CLASSIFIER_MODEL verdict, which must normalize to exactly "complex"
       to select pi. Everything else lands on glm: "complexity", "complexity:
       low", "complexではない", "complex?", "「complex」", an empty answer, a
       truncated answer (finish_reason not in (None, "stop")), or one of the
       narrow exceptions below. Only the one known-good answer passes, which is
       what closes the open world a negation blocklist cannot close — the
       normalization strips from the string's two ends only, so a single
       unexpected character anywhere in the middle means no match, i.e. glm.
       The cost is recall: a verdict that *means* complex but carries quotes,
       a code fence or a prefix resolves to glm. That is intended, not a bug.

    `title` and `body` are untrusted issue text and are sanitized here. This is
    deliberately independent of the handler's own sanitize_text() call for the
    agent loop's initial message (both engines share that one; it is untouched).

    Returns {"engine", "verdict", "reason", "verdict_recognized"}.
    `verdict_recognized` is False only on the classification path, when the
    normalized verdict is neither "complex" nor "simple" (so the caller can
    emit `::warning::` instead of letting `auto` degrade to a permanent silent
    glm). The explicit and label paths never set it False: there is no verdict.
    """
    configured = (configured or "").strip()
    if configured in ("glm", "pi"):
        return {
            "engine": configured,
            "verdict": None,
            "reason": f"vars.AI_HANDLER_ENGINE={configured} の明示指定（自動分類なし）",
            "verdict_recognized": True,
        }

    labels = tuple(labels or ())
    if "simple-request" in labels and "complex-request" in labels:
        return {
            "engine": "glm",
            "verdict": None,
            "reason": "simple-request と complex-request が同時に付与されているため"
            "有界側の simple-request を優先（自動分類なし）",
            "verdict_recognized": True,
        }
    for label, engine in (("simple-request", "glm"), ("complex-request", "pi")):
        if label in labels:
            return {
                "engine": engine,
                "verdict": None,
                "reason": f"{label} ラベルによる指定（自動分類なし）",
                "verdict_recognized": True,
            }

    request_fn = request_fn or _openrouter_request
    safe_title = sanitize_text(title, max_len=300)
    safe_body = sanitize_text(body, max_len=4000)

    # 名指しされたファイルパスの件数を「数えられる事実」としてuser messageに注入する。
    # systemプロンプトの文言は変えない——issue #102（`modules/ai/bottle.nix`,
    # `home/ai/niri-config.kdl`, `home/ai/noctalia-settings.toml` の削除。3ファイル・
    # 2ディレクトリ）が simple と誤分類されたのは、既存のルール（複数ファイルなら
    # complex）が足りなかったからではなく、軽量モデルが自分のルールを守らなかったから。
    # 抽出はモデルが実際に読むサニタイズ後のテキストに対して行う（切り詰めで本文から
    # 消えたパスを件数に数えないため）。0〜1件なら行を足さない——issue #92/#93のように
    # パスを名指ししないissueに対しては完全なno-opで、既存プロンプトと同一になる。
    paths = extract_path_mentions(f"{safe_title}\n{safe_body}")
    path_hint = ""
    if len(paths) >= 2:
        path_hint = (
            f"このissueの本文は {len(paths)} 個の異なるファイルパスに言及しています: "
            f"{', '.join(paths)}。\n"
            "2つ以上のファイルまたはディレクトリに触れる作業は、上記のルールのとおり"
            "通常 complex と判定してください。\n"
        )

    classify_prompt = (
        "次のNixOS設定リポジトリのissueに対応する作業の複雑性を判定してください。\n"
        "単一ファイルの自明な追加・削除なら simple、複数ファイルの調査や"
        "試行錯誤を伴うなら complex です。\n"
        f"{path_hint}"
        "simple か complex のどちらか一語だけを出力してください（引用符・"
        "コードブロック・句読点・説明は付けないでください）。\n\n"
        f"--- タイトル ---\n{safe_title}\n\n"
        f"--- 本文 ---\n{safe_body}\n"
    )

    try:
        # HTTP呼び出しは既存ヘルパをそのまま再利用する（urllibの再実装はしない）。
        # _openrouter_request は環境から OPENROUTER_API_KEY を読む。`tools` キーは
        # 不要。`max_tokens` は**付けない**——完全一致判定は切り詰め応答に対しても
        # 安全側（glm）に落ちるので安全上の意義が無く、一方で reasoning token を
        # 使うモデルで空応答を誘発し auto が無警告で常時 glm に縮退するリスクを
        # 上げるだけになる。
        response = request_fn(
            {
                "model": CLASSIFIER_MODEL,
                "temperature": 0,
                "messages": [
                    {
                        "role": "system",
                        "content": "あなたは作業量の分類器です。simple か complex の一語のみを返します。",
                    },
                    {"role": "user", "content": classify_prompt},
                ],
            }
        )
        choice = response["choices"][0]
        verdict = (choice["message"].get("content") or "").strip()
        # finish_reason は content と違い choices[0] の直下にある。None は
        # 「このフィールドを返さないプロバイダ」として許容する（欠落で auto 全体が
        # 原因不明に glm へ固定されるのを避ける）。それ以外の非 "stop" 値だけを、
        # 切り詰めが偶然 "complex" への一致を作る唯一の経路として弾く。
        finish_reason = choice.get("finish_reason")
    except (KeyError, IndexError, TypeError, OSError, ValueError) as error:
        # 失敗時は必ず glm にフォールバックする（pi ではない）。pi分岐は
        # PI_MAX_TURNS/PI_MAX_TOOL_CALLS を実質無制限にし、job の
        # `timeout-minutes: 90` だけが歯止めになっているため、分類が不安定なときに
        # 予算無制限側へ倒すのは既存の安全設計と矛盾する。`except Exception` には
        # しない（本当のバグを握り潰すため）が、この`try`ブロックは`request_fn`の
        # 実HTTP呼び出しを含むため、ネットワーク障害（urllibの`OSError`系）と
        # JSONデコード失敗（`ValueError`系、`json.JSONDecodeError`はその派生）も
        # レスポンス構造の不整合（KeyError/IndexError/TypeError）と同じ「外部呼び出し
        # の予期された失敗モード」として扱う必要がある——ここだけ狭めると、通信エラー
        # 1つでフォールバックせずジョブそのものが落ちてしまう。
        return {
            "engine": "glm",
            "verdict": None,
            "reason": "自動分類が失敗したため安全側の glm にフォールバック: "
            f"{type(error).__name__}: {error}",
            "verdict_recognized": False,
        }

    normalized = verdict.strip().lower().strip(_VERDICT_STRIP_CHARS)
    engine = "pi" if normalized == "complex" else "glm"
    reason = f"{CLASSIFIER_MODEL} の自動分類結果: {verdict!r}"
    if finish_reason not in (None, "stop"):
        engine = "glm"
        reason = (
            f"{CLASSIFIER_MODEL} の応答が途中で終了したため（finish_reason="
            f"{finish_reason!r}）安全側の glm にフォールバック: {verdict!r}"
        )
    return {
        "engine": engine,
        "verdict": verdict,
        "reason": reason,
        "verdict_recognized": normalized in _RECOGNIZED_VERDICTS,
    }


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
