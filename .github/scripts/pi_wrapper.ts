/**
 * pi extension for the ai-issue-autofix.yml pilot (plan: .omc/plans/pi-harness-migration.md).
 *
 * Like ai_pipeline.py and glm_agent.py this file must always be loaded from a
 * `main` checkout ($RUNNER_TEMP/trusted/.github/scripts/pi_wrapper.ts, passed to
 * pi as an absolute `-e` path). It constrains the model, so a branch that could
 * rewrite it could also widen its own permissions. See AGENTS.md.
 *
 * The six tools here are pure dispatch glue: every containment, allow-list and
 * timeout decision lives in ai_pipeline.py's agent-* subcommands, which this
 * file shells out to. Two responsibilities are *not* glue, because pi has no
 * equivalent (see .omc/research/pi-harness-spike.md (e) and (f)):
 *   - turn / tool-call budgets, which pi's agent loop does not implement;
 *   - scrubbing credentials out of the child environment, which pi cannot do
 *     for us because extensions run inside the pi process.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { spawnSync } from "node:child_process";
import { writeFileSync } from "node:fs";

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} must be set (see .github/scripts/pi_run.sh)`);
  return value;
}

const PIPELINE = required("PI_AGENT_PIPELINE");
const REPO_ROOT = required("PI_AGENT_REPO_ROOT");
const STATE_FILE = required("PI_AGENT_STATE_FILE");
const OUTPUT_DIR = required("PI_AGENT_OUTPUT_DIR");
const SUBMIT_MARKER = required("PI_AGENT_SUBMIT_MARKER");
const COMMIT_TRAILER = process.env.PI_AGENT_COMMIT_TRAILER ?? "";
const MESSAGE_PREFIX = process.env.PI_AGENT_MESSAGE_PREFIX ?? "";

// Mirrors glm_agent.run_agent_loop()'s live defaults. Overridable so the YAML
// can track them if the 15/40 -> 25/60 change lands without editing this file.
const MAX_TURNS = Number(process.env.PI_MAX_TURNS ?? 15);
const MAX_TOOL_CALLS = Number(process.env.PI_MAX_TOOL_CALLS ?? 40);

// max(ai_pipeline.COMMAND_TIMEOUTS) + margin: run_command handles its own
// timeout internally, so this outer bound only catches a wedged interpreter.
const RUN_COMMAND_TIMEOUT_MS = 360_000;
const DEFAULT_TIMEOUT_MS = 60_000;

// Same deny-list as ai_pipeline._run_env(). That one protects the nix/niri
// grandchild; this one keeps the credentials out of the python process itself.
const SECRET_ENV_RE = /(TOKEN|KEY|SECRET|PASSWORD|_API_)/i;
const ALWAYS_DENIED_ENV = ["OPENROUTER_API_KEY", "GH_TOKEN", "GITHUB_TOKEN"];

export function childEnv(source: NodeJS.ProcessEnv = process.env): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [name, value] of Object.entries(source)) {
    if (ALWAYS_DENIED_ENV.includes(name) || SECRET_ENV_RE.test(name)) continue;
    env[name] = value;
  }
  return env;
}

/** Translate one agent-* envelope into the text glm_agent.py's loop would show
 *  the model: bare on success, "DENIED: "/"ERROR: " prefixed otherwise. */
export function renderEnvelope(raw: string): string {
  let envelope: { kind?: unknown; result?: unknown };
  try {
    envelope = JSON.parse(raw);
  } catch {
    return `ERROR: unparseable envelope from ai_pipeline.py: ${raw.slice(0, 200)}`;
  }
  const result = String(envelope.result ?? "");
  if (envelope.kind === "ok") return result;
  if (envelope.kind === "denied") return `DENIED: ${result}`;
  return `ERROR: ${result}`;
}

function callPipeline(args: string[], input: string, timeoutMs: number): string {
  const spawned = spawnSync("python3", [PIPELINE, ...args], {
    input,
    env: childEnv(),
    encoding: "utf8",
    timeout: timeoutMs,
    maxBuffer: 16 * 1024 * 1024,
  });
  if (spawned.stderr) process.stderr.write(spawned.stderr);
  if (spawned.signal) return `ERROR: subprocess killed by signal ${spawned.signal}`;
  if (spawned.error) return `ERROR: ${spawned.error.message}`;

  const line = (spawned.stdout ?? "").trim().split("\n").pop() ?? "";
  if (!line) return `ERROR: ${args[0]} produced no output (exit ${spawned.status})`;
  return renderEnvelope(line);
}

function textResult(text: string) {
  return { content: [{ type: "text" as const, text }], details: undefined };
}

const sandboxArgs = ["--repo-root", REPO_ROOT, "--state-file", STATE_FILE];

/** How the harness stops the loop. NOT ctx.shutdown(): print/json mode never
 *  binds a shutdown handler, so AgentSession's `this._extensionShutdownHandler?.()`
 *  is a silent no-op there. ctx.abort() has no handler bound either, but its
 *  fallback path (`void this.abort()`) does end the agent operation. */
type Stoppable = { abort: () => void };

export default function (pi: ExtensionAPI) {
  let turns = 0;
  let toolCalls = 0;
  let halted: string | null = null;

  function halt(ctx: Stoppable, reason: string): string {
    halted = reason;
    ctx.abort();
    return reason;
  }

  const register = (
    name: string,
    description: string,
    parameters: ReturnType<typeof Type.Object>,
    run: (params: Record<string, unknown>, ctx: Stoppable) => string,
    executionMode?: "sequential",
  ) => {
    pi.registerTool({
      name,
      label: name,
      description,
      parameters,
      ...(executionMode ? { executionMode } : {}),
      async execute(
        _toolCallId: string,
        params: Record<string, unknown>,
        _signal: unknown,
        _onUpdate: unknown,
        ctx: Stoppable,
      ) {
        return textResult(run(params, ctx));
      },
    });
  };

  register(
    "list_dir",
    "リポジトリ内のディレクトリの内容を一覧表示する。",
    Type.Object({
      path: Type.String({ description: "リポジトリルートからの相対パス（例: home/ai）。" }),
    }),
    (params) =>
      callPipeline(
        ["agent-list-dir", ...sandboxArgs, "--path", String(params.path ?? "")],
        "",
        DEFAULT_TIMEOUT_MS,
      ),
  );

  register(
    "read_file",
    "リポジトリ内のファイルを読む（.git/** と secrets/** は不可）。",
    Type.Object({
      path: Type.String({ description: "リポジトリルートからの相対パス。" }),
    }),
    (params) =>
      callPipeline(
        ["agent-read-file", ...sandboxArgs, "--path", String(params.path ?? "")],
        "",
        DEFAULT_TIMEOUT_MS,
      ),
  );

  register(
    "write_file",
    "許可パスにファイルを書き込む（既存なら全体を置き換える）。",
    Type.Object({
      path: Type.String({ description: "modules/ai, home/ai, tests/ai 直下の許可パス。" }),
      content: Type.String({ description: "ファイルの完全な内容。" }),
    }),
    (params) =>
      callPipeline(
        ["agent-write-file", ...sandboxArgs, "--path", String(params.path ?? "")],
        String(params.content ?? ""),
        DEFAULT_TIMEOUT_MS,
      ),
    "sequential",
  );

  register(
    "delete_file",
    "許可パスのファイルを削除する（追跡済みか、今回書いたファイルのみ）。",
    Type.Object({
      path: Type.String({ description: "modules/ai, home/ai, tests/ai 直下の許可パス。" }),
    }),
    (params) =>
      callPipeline(
        ["agent-delete-file", ...sandboxArgs, "--path", String(params.path ?? "")],
        "",
        DEFAULT_TIMEOUT_MS,
      ),
    "sequential",
  );

  register(
    "run_command",
    "検証コマンドを実行する（nix / niri / nix-instantiate のみ）。",
    Type.Object({
      argv: Type.Array(Type.String(), {
        description: 'argv配列（例: ["niri", "validate", "-c", "home/ai/niri.kdl"]）。',
      }),
    }),
    (params) => {
      const argv = Array.isArray(params.argv) ? params.argv.map(String) : [];
      // `--` must follow the subcommand's own options: ai_pipeline.main() splits
      // on the first `--` before argparse runs, so the model's argv can never
      // claim a flag belonging to the harness.
      return callPipeline(
        ["agent-run-command", ...sandboxArgs, "--", ...argv],
        "",
        RUN_COMMAND_TIMEOUT_MS,
      );
    },
    "sequential",
  );

  register(
    "submit",
    "作業完了を宣言してループを終了する。",
    Type.Object({
      title: Type.String({ description: "変更内容を要約したPRタイトル（日本語可、60文字程度）。" }),
      summary: Type.String({ description: "何をどう変えたかの要約。箇条書き推奨。" }),
    }),
    (params, ctx) => {
      const text = callPipeline(
        [
          "agent-submit",
          "--output-dir",
          OUTPUT_DIR,
          "--title",
          String(params.title ?? ""),
          "--summary",
          String(params.summary ?? ""),
          ...(COMMIT_TRAILER ? ["--commit-trailer", COMMIT_TRAILER] : []),
          ...(MESSAGE_PREFIX ? ["--message-prefix", MESSAGE_PREFIX] : []),
        ],
        "",
        DEFAULT_TIMEOUT_MS,
      );
      if (!text.startsWith("DENIED: ") && !text.startsWith("ERROR: ")) {
        // pi_run.sh reads this marker to reproduce glm's `if result["aborted"]`.
        writeFileSync(SUBMIT_MARKER, `${text}\n`, "utf8");
        halt(ctx, "submit が呼ばれたため終了します。");
      }
      return text;
    },
  );

  // pi's agent loop is an unbounded `while (true)` with no turn or tool-call
  // ceiling of its own (spike (e)), so the budget glm_agent.run_agent_loop()
  // enforces has to be rebuilt here. Blocking is what actually contains the
  // model; abort() only saves the runner the remaining round trips.
  pi.on("tool_call", (_event: unknown, ctx: Stoppable) => {
    if (halted) return { block: true, reason: halted };
    if (toolCalls >= MAX_TOOL_CALLS) {
      const reason = halt(ctx, `ツール呼び出し上限(${MAX_TOOL_CALLS})に到達したため中断しました。`);
      process.stderr.write(`::error::${reason}\n`);
      return { block: true, reason };
    }
    toolCalls += 1;
  });

  pi.on("turn_end", (_event: unknown, ctx: Stoppable) => {
    turns += 1;
    if (!halted && turns >= MAX_TURNS) {
      const reason = halt(ctx, `応答ターン上限(${MAX_TURNS})に到達し submit が呼ばれませんでした。`);
      process.stderr.write(`::error::${reason}\n`);
    }
  });
}
