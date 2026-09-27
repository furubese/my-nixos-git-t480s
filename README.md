# t480s-desktop-nixos

ホスト `t480s`（ThinkPad T480s、AMD搭載、ユーザー `fse`）のためのgit管理NixOS構成リポジトリ。
`flake-parts` + Home Manager + sops-nix を統合し、AIによる編集対象を明確に分離した構造で管理する。

## ディレクトリ構成

```
flake.nix                    # flake-parts骨格。nixosConfigurations.t480s と perSystem.checks を定義
flake.lock                   # 初回オンマシン `nix flake lock` 実行後に生成される（未生成）
hosts/t480s/
  configuration.nix          # ホスト本体設定（旧ルート直下のconfiguration.nixを移設）
  hardware-configuration.nix # ハードウェア固有設定（旧ルート直下のものをそのまま移設）
modules/
  packages.nix               # AI編集可能。environment.systemPackages はここだけで管理
  desktop.nix                 # スタブのみ（未実装・未import）。KDE/niri設定は次回以降
  overlays.nix                 # スタブのみ（未実装・未import）
home/
  fse.nix                    # Home Manager によるユーザー環境設定
secrets/
  secrets.yaml.example        # 平文の秘密情報テンプレート（暗号化前の雛形）
.sops.yaml                    # sops-nix の鍵・暗号化ルール定義（recipientはプレースホルダー）
tests/
  smoke.nix                   # checks.smoke として配線済み。modules/packages.nix のみをimport
  desktop-full.nix            # プレースホルダーのみ。checksに未登録
.github/workflows/
  check-light.yml              # 通常PR用の軽量ビルド・テストCI
  check-desktop.yml            # 手動トリガー専用（workflow_dispatchのみ）。desktop.nix未実装のため
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

## 未実装・既知の制限事項

- AI駆動のIssue→PR自動化（`ai-issue-handler.yml`）はこのセッションでは実装していない
- GitHubリモート作成・Cachix接続はこのセッションでは行っていない
- `check-desktop.yml` は手動トリガー（`workflow_dispatch`）専用。`modules/desktop.nix` が未実装のスタブのため、PRで自動実行されないようにしている
- `check-light.yml` は `CACHIX_AUTH_TOKEN` が未設定の間、Cachixのステップで失敗する（想定通りであり、バグではない）
