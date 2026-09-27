# NixOS × AIパイプライン アーキテクチャ

## 前提・決定事項

- 対象アーキテクチャ：x86-64（GitHub提供の標準ランナーと一致、追加措置不要）
- リポジトリ：**パブリック**（GitHub Actionsの分数制限を撤廃するため）
- バイナリキャッシュ：**Cachix**（無料枠5GB、自前ビルド分のみ消費）
- デスクトップ環境：KDE/niriを含むフル構成を予定
- CI実行時間：問題なし（許容範囲）

## 全体フロー

```
[Issue作成]「パッケージXを入れて」
    ▼
[AIエージェント] configuration.nix編集 → ブランチ作成 → PR作成
    ▼
[GitHub Actions: PR時]
    1. nix build（ビルド検証）
    2. nix flake check（nixosTest：軽量/フル 使い分け）
    3. Cachixへプッシュ（自前ビルド分のみ）
    ▼
[人間がPRレビュー・マージ]
    ▼
[対象マシンへの反映]（手動 or 半自動デプロイ）
```

## 1. リポジトリ構成

```
nixos-config/
├── flake.nix
├── flake.lock
├── hosts/
│   └── myhost/
│       ├── configuration.nix      ← ホスト全体の宣言
│       └── hardware-configuration.nix
├── modules/
│   ├── packages.nix                ← AIの編集対象をここに限定
│   ├── desktop.nix                 ← KDE/niri設定
│   └── overlays.nix                ← 自前ビルド・パッチ（Cachix対象）
├── tests/
│   ├── smoke.nix                   ← 軽量テスト（毎PR）
│   └── desktop-full.nix            ← フルデスクトップ起動テスト（限定トリガー）
└── .github/
    └── workflows/
        ├── check-light.yml         ← 通常PR用
        ├── check-desktop.yml       ← デスクトップ関連変更時のみ
        └── ai-issue-handler.yml    ← issue→AI編集→PR
```

**設計原則**：AIの編集対象を`modules/packages.nix`のような限定ファイルに絞ることで、ブートローダーやハードウェア設定など重要な箇所を誤って壊すリスクを構造的に減らす。

## 2. Issue → AI編集 → PR作成

```yaml
# .github/workflows/ai-issue-handler.yml
on:
  issues:
    types: [opened, labeled]

jobs:
  ai-edit:
    if: contains(github.event.issue.labels.*.name, 'package-request')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: AIエージェント実行
        run: |
          claude --print "issue本文: ${{ github.event.issue.body }}
          modules/packages.nix にパッケージを追記し、
          新しいブランチでPRを作成してください。
          既存の記述形式を厳守し、他のファイルは変更しないこと。" \
          --allowedTools "Edit,Bash(git:*),Bash(gh:*)"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

**ポイント**：AIの権限をプロンプトレベルで限定し、可能であればCODEOWNERSやブランチ保護で他ファイルへの変更を検知・拒否する。

## 3. CI検証（2段階に分離）

### 軽量チェック（毎PR）

```yaml
# .github/workflows/check-light.yml
on:
  pull_request:
    paths: ['hosts/**', 'modules/packages.nix']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v27
      - uses: cachix/cachix-action@v15
        with:
          name: <your-cache-name>
          authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
      - name: ビルド検証
        run: nix build .#nixosConfigurations.myhost.config.system.build.toplevel
      - name: 軽量テスト（起動・パッケージ存在確認）
        run: nix build .#checks.x86_64-linux.smoke -L
```

```nix
# tests/smoke.nix
{ pkgs, ... }:
pkgs.nixosTest {
  name = "smoke";
  nodes.machine = { ... }: { imports = [ ../hosts/myhost/configuration.nix ]; };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("which <installed-package>")
  '';
}
```

### フルデスクトップテスト（デスクトップ関連変更時のみ）

```yaml
# .github/workflows/check-desktop.yml
on:
  pull_request:
    paths: ['modules/desktop.nix']

jobs:
  desktop-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v27
      - uses: cachix/cachix-action@v15
        with:
          name: <your-cache-name>
          authToken: '${{ secrets.CACHIX_AUTH_TOKEN }}'
      - name: フルデスクトップ起動テスト
        run: nix build .#checks.x86_64-linux.desktop-full -L
```

```nix
# tests/desktop-full.nix
{ pkgs, ... }:
pkgs.nixosTest {
  name = "desktop-full";
  nodes.machine = { ... }: {
    imports = [ ../hosts/myhost/configuration.nix ];
  };
  testScript = ''
    machine.wait_for_x()
    machine.wait_for_unit("graphical.target")
    machine.succeed("pgrep niri")
  '';
}
```

`paths`フィルタでトリガーを分離し、パッケージ追加だけのPRは軽量チェックのみ、デスクトップ設定変更時のみ重いテストを実行する。

## 4. Cachix運用

- nixpkgs標準パッケージ（KDE/niriが素の状態であれば含む）は`cache.nixos.org`から取得されるため、Cachixの容量は消費しない
- Cachixの容量を消費するのは、`overlays.nix`内の自前ビルド・パッチ、およびnixosTestが生成するVMクロージャ
- 容量超過時は最近アクセスされていないパスから自動退避（エラーで停止するのではなく、次回そのパスが必要な際に再ビルドが走る）
- 蓄積が気になる場合は`cachix pin`と`--keep-revisions`で保持世代数を制限する運用を検討

## 5. マージ後のデプロイ

対象マシンの運用形態に応じて選択：

| 方式 | 内容 | 前提条件 |
| --- | --- | --- |
| 手動 | `git pull && sudo nixos-rebuild switch --flake .` を自分で実行 | 追加インフラ不要、最もシンプル |
| 半自動 | GitHub ActionsからSSH経由でデプロイジョブを実行 | 対象マシンが外部からSSH到達可能、デプロイ専用鍵をSecretsに保管 |

**安全策**：いきなり`switch`で永続適用せず、`nixos-rebuild test`（再起動で消える一時適用）→ヘルスチェック→`switch`の2段階にする。`test`適用後に問題が出れば再起動するだけで前の世代に自然に戻る。

## 6. 権限・安全設計

- AIエージェントの書き込み範囲：`modules/packages.nix`のみ
- マージ条件（ブランチ保護ルール）：`check-light.yml`は常に必須、デスクトップ関連変更時は`check-desktop.yml`も必須
- デプロイ権限：AIには持たせず、人間のマージ操作を起点とする

## 段階的ロードマップ

| 段階 | 内容 |
| --- | --- |
| 1 | issue→AI編集→PR作成、軽量CIのみ、デプロイは手動 |
| 2 | デスクトップ変更時のフルテストを追加 |
| 3 | Cachixの蓄積状況を見ながらpin運用を確立 |
| 4 | 信頼が積み上がった段階でデプロイの半自動化を検討 |

いきなり全自動（段階4）を目指さず、段階1から実績を積みながら自動化範囲を広げるのが現実的。
