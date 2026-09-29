# issue #24: Bottles（Wineボトル管理GUI）のインストール。
#
# Bottlesはパッケージ単体では完結せず、初回起動時に公式のプレビルドWineランナー
# （Soda/Caffe等）をダウンロードして実行する。ランナーはFHS環境を前提とした
# 未パッチの動的リンクバイナリ（ELFインタプリタ = /lib64/ld-linux-x86-64.so.2）
# のため、素のNixOSではローダが解決できず起動に失敗する。
# 「パッケージだけ入って実際には動かない」状態（modules/packages.nix のコメントに
# 残る旧設計の失敗パターン）を避けるため、programs.nix-ld を有効化し、
# ランナーが必要とする基本ライブラリを NIX_LD_LIBRARY_PATH で解決できるようにする。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ bottles ];

  programs.nix-ld = {
    enable = true;
    # プレビルドWineランナーが動的リンクする基本ライブラリ。
    # Windowsアプリ側でさらに不足が出た場合はここへ追記する。
    libraries = with pkgs; [
      alsa-lib # winealsa.drv（ALSAオーディオ）
      fontconfig
      freetype # Wineのフォントレンダリング
      glib
      libGL # OpenGL（libglvnd経由）
      libdrm
      libpulse # winepulse.drv（PipeWire/PulseAudioオーディオ）
      libxkbcommon
      mesa # GLベンダー（libGLX_mesa等）の発見用
      stdenv.cc.cc # libstdc++ / libgcc_s
      vulkan-loader # DXVK等のVulkan翻訳層用
      xorg.libX11
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXinerama
      xorg.libXrandr
      xorg.libXrender
      xorg.libXxf86vm
      xorg.libxcb
      zlib
    ];
  };
}
