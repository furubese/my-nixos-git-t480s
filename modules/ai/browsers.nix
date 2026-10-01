# issue #31: ブラウザの整備
# Firefox は NixOS 標準の programs.firefox で有効化する。
#
# Waterfox について:
#   当初 nixpkgs の waterfox パッケージを導入しようとしたが、このリポジトリで
#   ピン留めされている nixpkgs リビジョンには waterfox が存在せず、
#   「undefined variable 'waterfox'」の評価エラーで CI が失敗したため導入を見送る。
#   Waterfox が必要な場合は flake input や overlay で nixpkgs 外から提供する
#   必要がある（AI の編集範囲である modules/ai 以下では対応不可）。
{ ... }:
{
  # Firefox（ラッパー付き firefox が environment.systemPackages に追加される）
  programs.firefox.enable = true;

  # niri (Wayland) 環境向けの設定。
  # Firefox 121 以降は Wayland を自動検出するため基本的に不要だが、
  # 明示しておくことでネイティブ Wayland 起動を確実にする（無害）。
  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";
}
