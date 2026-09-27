# 構築ログ（記事用）

このファイルは「git で NixOS を管理する」プロジェクトを構築していく過程の意思決定・やり取りを、後で記事にまとめるために記録するログです。

---

## 2026-09-28 セッション開始

- `story.md`（NixOS × AI パイプラインのアーキテクチャ設計）を読み込み、これをベースに実際のリポジトリ構築を開始。
- 作業環境は Fedora（NixOS 本体ではない）。対象マシンは `t480s`（ThinkPad T480s）と推測されるが、既存の NixOS インストール状況は未確認。
- Deep Interview（ソクラテス式の要件確認）を開始し、以下のトップレベル・コンポーネント候補をユーザーに提示：
  1. リポジトリ基盤（flake.nix / hosts 構成）
  2. CI検証とCachix
  3. AI駆動 Issue→PR 自動化
  4. デプロイ運用
  5. 記事用ログ記録（このファイル自体）

## Deep Interview で確定した意思決定

- **対象機の状態**：t480s実機にはNixOSが未インストール。ユーザーがNixOS ISOで最小インストールを実施し、生成された `configuration.nix` / `hardware-configuration.nix` を提供。ホスト名はまだ `nixos`（プレースホルダー）、ユーザー名は `fse`。
  - 理由：ゼロからの新規セットアップであり、既存の稼働中システムの取り込みではないと判明したことで、作業範囲が「リポジトリ整備」中心に定まった。
- **ディレクトリ構造は flake-parts + Home Manager で構造化**：ホストは今後t480s以外にも増える見込みのため、最初から抽象化しておく判断。
  - 理由（Contrarianモードでの再確認）：単一ホストなら過剰設計になり得るが、多ホスト化を見越しているとの明言があったため採用継続。
- **AI駆動Issue→PR自動化（ai-issue-handler.yml）は今回スキップ**：ディレクトリ構成（`modules/packages.nix`分離など）はAI編集しやすさを意識するが、実際のworkflowファイルは作らず将来の拡張点として保留。
- **CI/Cachixはローカルでworkflowファイルのみ用意**：GitHubリモートリポジトリもCachixアカウントも未作成のため、今回は実接続・実行検証はできない。プレースホルダー付きで用意する。
- **デプロイは手動のみ**：`git pull && sudo nixos-rebuild switch --flake .` を自分で実行する運用。半自動SSHデプロイは将来検討。
- **ハードウェア構成の事実確認**：`hardware-configuration.nix` に `kvm-amd` が含まれておりIntel想定のT480sと矛盾すると指摘したが、ユーザーより「これが実機」との回答。AMD搭載モデルとして扱う。
- **シークレット管理は sops-nix を最初から導入**：公開リポジトリ運用のため、Wi-Fiパスワードやパスワードハッシュなど将来発生し得る秘密情報をリポジトリ整備の最初の段階から暗号化管理する方針に決定。
- **最終曖昧度スコア：18%**（閾値20%以下で確定）。10ラウンドのソクラテス式対話を経て収束。

## omc-planコンセンサス（Planner/Architect/Critic）でのプランニング

- Deep Interviewの仕様書を基に、Planner→Architect→Criticのループを3ラウンド実施
- v1・v2はいずれもCriticが**REJECT**。主な指摘は「`flake.nix`のoutputsラッパーが実際には評価できない（裸の識別子参照）」「hostnameとflakeアトリビュートの不一致でデプロイコマンドが失敗する」「オンマシン初回手順でexperimental-features有効化の順序が間違っている」など、構造だけでなく「実機での初回ブートが本当に成功するか」を重視した指摘が中心だった
- 3ラウンド目でCriticが**APPROVE WITH CHANGES**、Architectも「構造上のブロッカーなし」と判定。最大の残課題は「フレッシュインストール直後のt480sには`git`が無く、`.git`付きでリポジトリを転送すると初手から詰む」という鶏卵問題で、解決策は「`.git`を含めずに転送し、Nixにただのディレクトリとして評価させる」という単純な方式に落ち着いた
- 最終計画（v4）は`.omc/plans/nixos-git-t480s-plan.md`に`pending approval`として保存
- Open Questions（desktop.nixの範囲、hostname改名、`.omc/`除外、SSH有効化）は全て計画の推奨案どおりで確定

## 実装フェーズ（team実行）

- GitButlerで`t480s-nixos-repo`ブランチを作成。既存の`configuration.nix`/`hardware-configuration.nix`/`story.md`/`docs/article-log.md`をベースラインコミットとして先にコミットし、`.omc/`を最初から`.gitignore`することで、内部検討資料（Deep Interview仕様書・本計画）をリポジトリ履歴に一切残さない判断を実行時にも徹底した
- 3並行ワーカーで実装：①`flake.nix`+`hosts/t480s/`、②`modules/`+`home/`+sops関連、③CI workflow+テスト+README
- 実装後、計画のIn-session Verification Steps 1〜7（相対パス解決・flakeアトリビュート整合・識別子束縛・シークレット混入・リモート未作成・GitButler履歴確認など）をすべて実行し通過を確認。特に`hosts/t480s/configuration.nix`が元ファイルとの差分で「imports追加・hostname変更・experimental-features追加」の3点のみであること、`hardware-configuration.nix`がバイト同一であることを`git show <baseline>`との比較で確認した
- オンマシンでの実際の`nix flake check`実行・`nixos-rebuild`実行は未実施（Non-Goal）。README記載の手順をユーザーが実機で試す段階

## GitHub公開・運用フェーズ

- ユーザーが自身でGitHubリポジトリ（`furubese/my-nixos-git-t480s`）を作成・push。ローカルの作業ディレクトリも`my-nixos-git-t480s`に改名
- Cachixの`CACHIX_AUTH_TOKEN`をGitHub Actions Secretsに登録。チャットに一時的に貼られたトークンは無効化・再発行し、新しいものを登録する運用にした（秘密情報をチャットや履歴に残さない判断の徹底）
- `check-light.yml`/`check-desktop.yml`のCachixキャッシュ名プレースホルダーを実名（`nixos-furubese-t480s-5gb`）に置換

## 追加機能：zsh + oh-my-zsh のNix管理化

- デフォルトシェルをzshにし、oh-my-zshを導入したいという要望を受け、システム側（ログインシェル切り替え・`/etc/shells`登録）とユーザー側（oh-my-zshのテーマ・プラグイン等）を分離して設計
  - 理由：ログインシェルの変更はシステム全体に影響するためNixOSモジュール（`modules/shell.nix`）に、oh-my-zshの中身は個人設定なのでHome Manager（`home/fse.nix`）に、と責務を分けた
- `modules/shell.nix`を新規追加し`hosts/t480s/configuration.nix`からimport。`home/fse.nix`に`programs.zsh.oh-my-zsh`設定を追加
- CIの`paths`フィルタを`modules/packages.nix`単体から`modules/**`に広げた（新しいモジュールを追加するたびに個別列挙するのは壊れやすいため）

## テスト→PRフローの確認（Deep Interview 2回目）

- 「Nixコード変更はテストを通してからPRを出してほしい」という要望を受けて短いDeep Interviewを実施。調査の結果、`check-light.yml`が既に`pull_request`トリガーで自動テストを実行する設計になっており、要望の大部分は既に満たされていることが判明
- GitHub Branch protection（必須ステータスチェック）による強制ブロックも検討したが、`check-light.yml`がpathsフィルタ付きのため、Nixコードを含まないPR（AGENTS.mdのみ等）に同じ必須チェックをかけると永久に判定待ちになりマージ不能になるという既知の落とし穴が判明。ユーザーの判断でブロック機構は導入しないことに決定
- 曖昧度8%で早期収束（新規実装が不要と分かったため、omc-planコンセンサスは経由せず直接実行）。`feat-zsh-ohmyzsh`（PR #1）と`docs-agents-md`（PR #2）を実際にPR化し、動作を確認する運びとした

## AI駆動Issue→PR自動化の実装（story.mdの構想を実現）

- 以前のDeep Interviewで意図的に見送っていた`ai-issue-handler.yml`を、ユーザーからの明示的な依頼を受けて実装
- 実装前に2点確認：①公開リポジトリでの起動条件（ラベルゲート方式を採用。ラベル付与にはtriage/write権限が必要なため、誰でも作成できるissueだけでは起動しない）、②ANTHROPIC_API_KEYの有無（未取得とのことで、Anthropic Consoleでの取得手順を案内）
- story.mdの元案から一歩進めて、AIには`modules/packages.nix`の編集のみを許可（`Bash`ツールなし）し、ブランチ作成・差分検証（対象ファイル以外が変更されていたら中断）・コミット・PR作成はワークフロー側の確定的な処理で行う設計にした
  - 理由：issue本文は信頼できない入力（プロンプトインジェクションの可能性）であり、AIの出力をそのままgit操作に使うのはリスクが高いため
- この開発環境にはGitHub Actionsを実行する手段が無く、`claude --print`/`--allowedTools`の実際の挙動は未検証のまま実装した旨をREADMEに明記
