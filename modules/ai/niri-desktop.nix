# niri + noctalia デスクトップ環境（NixOSモジュール）
#
# issue #17: niri + greetd + tuigreet によるログインフローを導入
# issue #21: 普段使いのFedora環境（niri + noctalia）に寄せた設定
#   - デスクトップ周辺パッケージ（alacritty / fuzzel / swaylock / brightnessctl / playerctl）
#   - catppuccinカーソル（frappe green）
#   - polkit（noctaliaのpolkit_agent用）/ gnome-keyring / PipeWire（wpctl用）
#
# 注意: noctalia本体はnixpkgsに存在しない（issue #21時点）。
# 導入にはflake.nixへのinput追加（github:noctalia-dev/noctalia-shell 等）が必要だが、
# flake.nixは本PRの編集スコープ外のため、pkgsにnoctaliaがあれば自動導入する
# ガードのみ用意している（input追加 + overlay後に有効になる）。
{ pkgs, lib, ... }:
{
  # niri本体（パッケージとxdg-desktop-portal-niriも導入される）
  programs.niri.enable = true;

  # ログイン: greetd + tuigreet → niriセッション
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd ${pkgs.niri}/bin/niri-session";
        user = "fse";
      };
    };
  };

  # Waylandコンポジタに必要なGPU/OpenGL周り
  hardware.graphics.enable = true;

  # polkit（noctaliaのpolkit_agentが対応するデーモン）
  security.polkit.enable = true;

  # シークレット保存（NetworkManager等のパスワード用）
  services.gnome.gnome-keyring.enable = true;

  # スクリーンロッカー（PAM設定込みで導入される）
  programs.swaylock.enable = true;

  # 音声: PipeWire（wpctlによる音量制御が依存）
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  # 輝度キー（brightnessctl）を非rootで使えるようにするudevルール
  services.udev.packages = [ pkgs.brightnessctl ];
  users.users.fse.extraGroups = [ "video" ];

  # Electron/Chromium系アプリをWaylandネイティブで動かす
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
  };

  # 日本語デスクトップに必要なCJKフォント
  fonts.packages = [ pkgs.noto-fonts-cjk ];

  environment.systemPackages =
    [
      pkgs.alacritty # ターミナル（niriのMod+T）
      pkgs.fuzzel # アプリランチャー（niriのMod+D）
      pkgs.brightnessctl # 輝度キー用
      pkgs.playerctl # メディアキー用
      pkgs.xwayland-satellite # X11アプリ用（niriが自動起動する）
    ]
    ++ lib.optionals (pkgs ? catppuccin-cursors.frappeGreen) [
      # カーソルテーマ（niri-config.kdlのcursor.xcursor-themeと対応）。
      # nixpkgs側のバリアント属性名が異なる場合はここを調整すること。
      pkgs.catppuccin-cursors.frappeGreen
    ]
    ++ lib.optionals (pkgs ? noctalia) [
      # noctalia本体（nixpkgs/overlayに存在する場合のみ導入される）
      pkgs.noctalia
    ];
}
