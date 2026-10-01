# issue #37: Steam を有効化する。
#
# 方針:
# - Steam 本体は programs.steam.enable で有効化する。environment.systemPackages に
#   pkgs.steam を足すだけでは FHS 互換環境や 32bit ランタイム等が整わない
#   （modules/packages.nix のコメントにある「パッケージだけ入れて有効化されない」
#   旧設計の失敗パターンを繰り返さない）。
# - NVIDIA GPU: プロプライエタリドライバを有効化し、Wayland (niri) 構成で必要な
#   modesetting を ON にする。ドライバは unfree だが、nixpkgs.config.allowUnfree は
#   hosts/t480s/configuration.nix で既に true。
# - AMD CPU: x86-64 なので Steam 動作に追加設定は不要（マイクロコード更新は
#   各マシンの hardware-configuration.nix が検出して設定する）。
{ pkgs, ... }:
{
  # Steam 本体と、ゲーム実行に必要な周辺設定（udev ルール等）をまとめて有効化
  programs.steam = {
    enable = true;
    # Steam Remote Play（スマホ/別PCからのゲーム配信）用のポート開放
    remotePlay.openFirewall = true;
  };

  # ゲーム用 OpenGL/Vulkan ランタイム。enable32Bit は古いゲームや
  # Steam ランタイム (pressure-vessel) の 32bit タイトルで必要。
  # programs.steam.enable でも mkDefault で有効化されるが、NVIDIA ドライバ構成で
  # 必ず入るよう明示しておく。
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # NVIDIA GPU ドライバ（プロプライエタリ）。
  # services.xserver.videoDrivers は X サーバーを有効にしていなくてもドライバの
  # 導入を制御するオプションで、Wayland (niri) 構成でもこの指定が正しい。
  # modesetting は Intel/AMD 内蔵 GPU 用に併記。NVIDIA GPU が実装されていない
  # マシンでは未使用のドライバとして同梱されるだけで、動作への実害はない。
  services.xserver.videoDrivers = [ "nvidia" "modesetting" ];

  hardware.nvidia = {
    # Wayland (niri) で NVIDIA GPU を使う場合に必須
    modesetting.enable = true;
    # サスペンド/レジューム時の VRAM 退避（ノートPC運用での安定化）
    powerManagement.enable = true;
    # カーネルモジュール種別（プロプライエタリ / オープン）の明示指定。
    #
    # CI失敗の修正: 現行 nixpkgs では hardware.nvidia.open のデフォルトは
    # null（未指定）で、この状態で NVIDIA モジュール内の assertion
    #   !cfg.open || (nvidia_x11.open != null)
    # を評価すると「expected a Boolean but found null」でビルドが落ちる。
    # そのため open は必ず true/false で明示する必要がある。
    # T480s 搭載の dGPU (GeForce MX150, Pascal 世代) はオープンカーネル
    # モジュールの対応対象（Turing 以降）外のため、プロプライエタリ側
    # (=false) を指定する。
    open = false;
  };
}
