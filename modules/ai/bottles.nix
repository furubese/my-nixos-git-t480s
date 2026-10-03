# Bottles (Wine プレフィックスマネージャ) の導入。issue #68 で重複を解消。
#
# PRレビュー指摘を反映した修正:
#
# 1. プレビルドWineランナーが動的リンクする基本ライブラリを復元した。
#    これらは不要になったわけではなく、issue #68 の bottle.nix / bottles.nix
#    統合時に誤って取り込むのを落としていた。Bottles がダウンロードする
#    プレビルドの Wine ランナーは FHS パスを前提に動的リンクするため、
#    FHS 非準拠の NixOS では必要な共有ライブラリをシステムプロファイルに
#    明示的に用意しておく必要がある。Windowsアプリ側でさらに不足が出た
#    場合はこのリストへ追記する。
#
# 2. X11 系ライブラリの属性名を現行名へ更新した。
#    統合時に移設した xorg.libX11 などの属性名は issue #59 の nixpkgs
#    パッケージ再編成より前の旧名だった。現行 nixpkgs では X11 系ライブラリは
#    xorg 属性セット配下からトップレベルの小文字名へ移動しているため
#    (modules/ai/niri-desktop.nix と同一の命名)、現行名へ置き換えた。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bottles

    # --- プレビルドWineランナーが動的リンクする基本ライブラリ ---
    # Windowsアプリ側でさらに不足が出た場合はここへ追記する。
    alsa-lib       # winealsa.drv（ALSAオーディオ）
    fontconfig
    freetype       # Wineのフォントレンダリング
    glib
    libGL          # OpenGL（libglvnd経由）
    libdrm
    libpulseaudio  # winepulse.drv（PipeWire/PulseAudioオーディオ）
    libxkbcommon
    mesa           # GLベンダー（libGLX_mesa等）の発見用
    stdenv.cc.cc   # libstdc++ / libgcc_s
    vulkan-loader  # DXVK等のVulkan翻訳層用

    # --- X11 系クライアントライブラリ（現行のトップレベル名） ---
    # Wine が Windows アプリ実行時に動的リンクする共有ライブラリ。
    # NixOS は FHS 非準拠のため、bottles の実行環境から解決できるよう
    # システムプロファイルに明示的に導入する。
    libx11
    libxcursor
    libxrandr
    libxi
    libxext
    libxrender
    libxfixes
    libxcomposite
    libxdamage
    libxinerama
    libxkbfile
  ];
}
