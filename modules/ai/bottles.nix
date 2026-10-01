# Bottles (Wine プレフィックスマネージャ) の導入。issue #68 で重複を解消。
# 旧 bottle.nix は xorg.libX11 などの xorg パッケージ名が最新で正しかったものの、
# ファイル名がアプリ名 (Bottles) と不一致で、旧 bottles.nix と内容が重複していた。
# そのため、正しいファイル名 bottles.nix 側に最新のパッケージ名の内容を統合した。
# 旧 bottle.nix は no-op 化済み (ファイル自体の削除は人間の作業領域)。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bottles

    # Wine が Windows アプリ実行時に動的リンクする xorg 共有ライブラリ。
    # NixOS は FHS 非準拠のため、bottles の実行環境から解決できるよう
    # システムプロファイルに明示的に導入する。
    xorg.libX11
    xorg.libXcursor
    xorg.libXrandr
    xorg.libXi
    xorg.libXext
    xorg.libXrender
    xorg.libXfixes
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXinerama
    xorg.libxkbfile
  ];
}