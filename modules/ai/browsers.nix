# issue #31: ブラウザの整備
# Firefox は NixOS 標準の programs.firefox で有効化し、
# Waterfox は nixpkgs の waterfox パッケージをシステムプロファイルに導入する。
{ pkgs, ... }:
{
  # Firefox（ラッパー付き firefox が environment.systemPackages に追加される）
  programs.firefox.enable = true;

  # Waterfox
  environment.systemPackages = with pkgs; [ waterfox ];

  # niri (Wayland) 環境向けの設定。
  # Waterfox は Firefox ESR ベースで Wayland がデフォルト無効のため、
  # MOZ_ENABLE_WAYLAND=1 でネイティブ Wayland 起動を有効にする。
  # Firefox 121 以降は Wayland を自動検出するため、この変数は無害。
  environment.sessionVariables.MOZ_ENABLE_WAYLAND = "1";
}
