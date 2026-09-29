# t480s-desktop-nixos

ホスト `t480s`（ThinkPad T480s、AMD搭載、ユーザー `fse`）のためのgit管理NixOS構成リポジトリ。
`flake-parts` + Home Manager + sops-nix を統合し、AIによる編集対象を明確に分離した構造で管理する。

<img width="1586" height="947" alt="image" src="https://github.com/user-attachments/assets/c8122012-db3e-4cec-8e32-fc53713eaab8" />


## ディレクトリ構成

```
flake.nix                    # flake-parts骨格。nixosConfigurations.t480s と perSystem.checks を定義
flake.lock                   # 初回オンマシン `nix flake lock` 実行後に生成される（未生成）
hosts/t480s/
  configuration.nix          # ホスト本体設定（旧ルート直下のconfiguration.nixを移設）
  hardware-configuration.nix # ハードウェア固有設定（旧ルート直下のものをそのまま移設）
modules/
  packages.nix               # 人間が編集。environment.systemPackages はここだけで管理
  desktop.nix                 # スタブのみ（未実装・未import）。KDE/niri設定は次回以降
  overlays.nix                 # スタブのみ（未実装・未import）
  ai/
    default.nix                # AI編集不可。直下の*.nixファイルを自動importするだけの器
    (AIが生成する *.nix/*.kdl/*.toml/*.json/*.conf がここに置かれる)
home/
  fse.nix                    # Home Manager によるユーザー環境設定
  ai/
    default.nix                # AI編集不可。modules/ai/default.nixと同じ役割（Home Manager側）
    (AIが生成するファイルがここに置かれる)
secrets/
  secrets.yaml.example        # 平文の秘密情報テンプレート（暗号化前の雛形）
.sops.yaml                    # sops-nix の鍵・暗号化ルール定義（recipientはプレースホルダー）
tests/
  smoke.nix                   # checks.smoke として配線済み。modules/packages.nix のみをimport
  desktop-full.nix            # プレースホルダーのみ。checksに未登録
  ai/
    default.nix                # AI編集可能パスとして予約済みだが、flake.nixに未配線（プレースホルダー）
.github/
  scripts/
    ai_pipeline.py              # AIパイプライン3ワークフロー共通の検証ロジック（必ずmainから取得）
  workflows/
    check-light.yml              # 通常PR用の軽量ビルド・テストCI（AIブランチはworkflow_dispatchで起動）
    check-desktop.yml            # 手動トリガー専用（workflow_dispatchのみ）。desktop.nix未実装のため
    ai-issue-handler.yml         # issueラベルからAIがNixコードを生成しPRを作成
    ai-issue-autofix.yml         # check-light失敗時にAIへ自動修正させる
    ai-issue-feedback.yml        # PRコメント（所有者のみ）でAIに追加修正させる
docs/
  article-log.md               # 実装過程の意思決定ログ
```

`.omc/**`（Deep Interviewの仕様書・計画書・セッション状態）はこのリポジトリの追跡対象・履歴のいずれにも含めていない（`.gitignore`で除外済み）。

## Step ⓿：t480s実機への転送（`.git`を含めないこと）

このセッションではGitHubリモートをまだ作成していない（Non-Goal）。そのため、作業機（Fedora）からt480s実機へこのリポジトリを転送する必要があるが、**`.git`ディレクトリは含めずに転送すること**。

```sh
rsync -a --exclude=.git ./ user@t480s:~/t480s-desktop-nixos/
```

または `scp -r` で丸ごとコピーした後、転送先で `rm -rf .git` してもよい。

**理由**：フレッシュインストール直後のt480sには `git` バイナリがまだ入っていない（`environment.systemPackages` に `git` を追加する `modules/packages.nix` 自体がまだ有効化されていないため、初期状態の `environment.systemPackages` は空）。もし `.git` 付きのまま転送すると、`nix flake lock` や `nix flake check` がgit操作（リビジョン特定など）を必要とし、`git` が無い状態で失敗してしまう。`.git` を含めずに転送すれば、Nixはこのディレクトリを単なるパス（`path:` フレーク）として評価するため、`git` が無くても手順を先に進められる。

`git` が使えるようになった後（下記Step⑥以降）、必要であれば実機側で改めて `git init` してよい。

## ネットワーク疎通の事前確認

flake inputのフェッチにはGitHubへの、システムクロージャのダウンロードには `cache.nixos.org` への到達性が必要。この最小インストールではWi-Fiがまだ設定されていない可能性があるため、先に疎通を確認しておく。

```sh
ping -c1 github.com
# または
ping -c1 cache.nixos.org
```

疎通しない場合は、先にネットワーク（Wi-Fi等）の設定を済ませること。

## オンマシン・ハンドオフ手順

すべての `nix` / `nixos-rebuild` 呼び出しには `NIX_CONFIG="experimental-features = nix-command flakes"` を付与する（このリポジトリではまだ `nix.settings.experimental-features` が有効化された世代に切り替わっていないため）。

1. ```sh
   NIX_CONFIG="experimental-features = nix-command flakes" nix flake lock
   ```
   生成された `flake.lock` は保管しておくこと。`.git` が無い間はコミットできないので、Step⑥で `git init` した際に追加すること。

2. ```sh
   NIX_CONFIG="experimental-features = nix-command flakes" nix flake check --no-build
   ```
   `--no-build` により `checks.smoke` の重いVMビルドを避け、まずは評価のみを確認する。

3. 初回のみ：
   ```sh
   sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild test --flake .#t480s
   ```

4. ヘルスチェック（以下をひととおり確認する）：
   - `systemctl is-system-running` — `running` ならOK。`degraded` の場合のみ `systemctl --failed` で内訳を確認する
   - `hostnamectl` — ホスト名が `t480s` になっているか確認
   - `nmcli general status` — ネットワークが疎通しているか確認
   - `which git` — 新しいパッケージリスト（`modules/packages.nix`）が有効化され `git` が使えるか確認
   - `journalctl -p err -b` — 軽く目を通す（新規インストールでは無害なerrログが出ることもあるため、明らかにこの世代由来と分かるエラーでなければ過度に気にしなくてよい）

   **何か問題があれば `switch` は実行せず、再起動すること。** `nixos-rebuild test` は再起動すると自動的に前世代へ戻るため安全。

5. ```sh
   sudo NIX_CONFIG="experimental-features = nix-command flakes" nixos-rebuild switch --flake .#t480s
   ```
   `#t480s` を明示するのは初回だけ必要。稼働中システムのホスト名がこの切り替えが完了するまでまだ旧名（`nixos`）のままだからである。

6. 2回目以降：
   ```sh
   git pull && sudo nixos-rebuild switch --flake .
   ```
   この時点で `git` が使えるようになっているので、必要であれば実機側で改めて `git init` し、通常のgitリポジトリとして運用してよい。

## sops-nix 鍵セットアップ

1. age鍵を生成する：
   ```sh
   age-keygen -o ~/.config/sops/age/keys.txt
   ```
2. `.sops.yaml` のプレースホルダーrecipient（`age1_REPLACE_WITH_YOUR_AGE_PUBLIC_KEY`）を、生成した実際のage公開鍵に置き換える。
3. `secrets/secrets.yaml.example` を `secrets/secrets.yaml` にコピーし、以下で暗号化する：
   ```sh
   sops secrets/secrets.yaml
   ```
   `secrets.yaml.example` は削除せず残しておくこと（雛形として）。

**未検証の前提（要注意事項）**：このリポジトリは sops-nix の NixOS モジュールが「`sops.secrets` が空・`sops.defaultSopsFile` 未設定」の状態でも評価が壊れない、という前提で設計されている。開発環境に `nix` コマンドが無く、この前提を実際には検証できていない。オンマシン手順のStep 2（`nix flake check --no-build`）で最初に確認してほしい項目である。もしここで失敗する場合は、この前提が誤りだった可能性が高い。

## 公開前チェックリスト

GitHubリモートを作成しこのリポジトリを公開する前に、以下をすべて確認すること。

- [ ] `.gitignore` に `.omc/` が含まれている
- [ ] `git ls-files .omc` と `git log --all --name-only -- '.omc/*'` がどちらも空である（`.omc/**` が追跡対象にも履歴にも一度も含まれていない）
- [ ] `secrets/` 配下に平文の実秘密が含まれていない（`secrets.yaml.example` はテンプレートなので問題ない）
- [ ] `git remote -v` にGitHub等の外部リモートが存在しない（GitButlerが自動追加する `gb-local` は問題ない、想定通り）

## AI駆動のIssue→PR自動化（3ワークフロー構成）

issue・CI失敗・PRコメントを起点に、AI（OpenRouter経由の`z-ai/glm-5.3`）が実際のNixコードを
生成してPRを作成・更新する仕組みです。`ai-issue-handler.yml`（issue起点）、
`ai-issue-autofix.yml`（CI失敗起点）、`ai-issue-feedback.yml`（PRコメント起点）の3つが、
`.github/scripts/ai_pipeline.py`という共通の検証ロジックを共有します。

- **セットアップ**：
  1. https://openrouter.ai/ でアカウントを作成し、`API Keys`からキーを発行。GitHub Secretsに
     `OPENROUTER_API_KEY`として登録（`gh secret set OPENROUTER_API_KEY`）。
     **チャットやコミットに絶対に貼らないこと。**
  2. `gh variable set AI_PIPELINE_ENABLED --body true` を実行してキルスイッチを有効化
     （未設定のままだとfail closedで全ワークフローが起動しません）。
- **AIの編集対象**：`modules/ai/**`, `home/ai/**`, `tests/ai/**`の直下のみ（サブディレクトリ禁止、
  `default.nix`禁止）。以前の設計（パッケージ名JSON配列のみ出力）から変更し、AIは実際のNixコード
  （`services.displayManager.lightdm.enable = true;`のようなサービス有効化を含む）を自由に生成
  できます。出力は`{"files": {"<パス>": "<内容>", ...}, "title": "...", "summary": "..."}`という
  JSONで、`files`のキーがすべて許可パスに収まっているかを`ai_pipeline.py`が機械的に検証します。
- **これはサンドボックスではない**：パスの許可リストは「どこに書き込めるか」だけを制限しており、
  「どのNixOSオプションを設定できるか」は制限していません（意図的：ユーザースコープ設定やサービス
  有効化まで扱えるようにするための設計変更です）。実質的な防御線は以下の多段の機械チェックと、
  **マージ前に人間が全差分を読むこと**です：
  1. 書き込まれたファイルパスが許可リスト（`modules/ai|home/ai|tests/ai` 直下、`default.nix`禁止）
     と完全一致することを`git add -A` + `git diff --cached --name-only`で確認（新規ファイルも捕捉）
  2. `nix-instantiate --parse`による構文チェックのみ実施（実際のビルド検証は`check-light.yml`に
     委ね、二重には行わない）
  3. 危険そうな構文（`hashedPassword`, `systemd.services`, `lib.mkForce`等）のアドバイザリスキャン
     ——ただしこれは**PRをブロックしません**。正規表現はattrsetのネストで容易に回避できるため、
     ブロックの根拠にはできないからです。ヒットした場合は`needs-careful-review`ラベルを付けて
     人間の注意を引くだけです
  4. issue本文・PRコメントは信頼できない入力として扱い、HTMLコメント除去等のサニタイズを経てから
     環境変数経由でPythonスクリプトに渡します（コマンドインジェクション・プロンプトインジェクション対策）
- **`.github/scripts/ai_pipeline.py`は必ず`main`から取得**：3ワークフローとも、このスクリプトを
  `path: _trusted`で`main`ブランチから都度checkoutします。AI制御下のブランチが自分自身を検証する
  ロジックを書き換えて検証をすり抜けることはできません。
- **`ai-issue-handler.yml`**：`package-request`ラベル付与（triage/write権限が必要）で起動。
  `ai/issue-N`ブランチをmainから強制リセットして作成し、AI生成タイトル・要約でPRを作成（以前は
  全PRが`packages: address #N`という同じタイトルで区別できない問題があったため変更）。
- **`ai-issue-autofix.yml`**：`check-light.yml`が自身のビルド失敗を検知して直接dispatchします
  （`workflow_run`イベント連鎖には依存しません——設計初期にこの方式を検討しましたが、
  `GITHUB_TOKEN`が作成したPRの初回ワークフロー実行には人間の手動承認が必要という仕様により
  実際には一度も発火しないことが判明したため、直接dispatch方式に変更しました）。試行上限3回、
  判定は`AI-Autofix-Attempt: true`という git trailerを持つコミット数で行います。
- **`ai-issue-feedback.yml`**：PRへのコメントに、**リポジトリ所有者のものだけ**反応します。
  修正をpushした後の追加返信コメントは基本的に行いません（Deep Interviewで確認済みの方針）。
  唯一の例外は、アドバイザリスキャンが危険そうな構文を検出した場合——このときはラベルに加えて
  PRコメントで明示的に注意喚起します。
- **未検証の前提**：この開発環境にはGitHub Actionsを実行する手段が無く、実際にOpenRouter APIを
  呼び出しての動作確認はできていません（`ai_pipeline.py`の各関数は単体テスト済み）。初回はテスト用
  issueで試し、想定通り動くか確認することを強く推奨します。5ラウンドの専門家レビュー（Architect/
  Critic）と、その後の追加スポットチェックを経てもなお新しいバグが見つかり続けたため
  （`docs/article-log.md`参照）、実機での最初の動作確認は特に注意深く見守ってください。
- **レビュー必須**：作成されるPRの本文にも明記していますが、AI生成の変更は必ず人間がレビューしてから
  マージしてください。`check-light.yml`のビルド検証も併せて確認すること。

## 未実装・既知の制限事項

- GitHubリモート作成・Cachix接続はこのセッションでは行っていない
- `check-desktop.yml` は手動トリガー（`workflow_dispatch`）専用。`modules/desktop.nix` が未実装のスタブのため、PRで自動実行されないようにしている
- `check-light.yml` は `CACHIX_AUTH_TOKEN` が未設定の間、Cachixのステップで失敗する（想定通りであり、バグではない）
- `tests/ai/default.nix` は許可パスとして予約されているだけで、`flake.nix`の`checks`には未配線（`flake.nix`はAI編集スコープ外のため、配線には人間の作業が必要）
- 旧設計（PR #11, #13等、`ai/packages-issue-*`ブランチ・パッケージ名JSON配列方式）で作られたPRは、この新設計への移行対象外。人間が個別に対応すること
