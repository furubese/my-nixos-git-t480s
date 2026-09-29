# niri + Noctalia デスクトップのシステム側設定 (issue #17)。
#
# ディスプレイマネージャについて:
#   lightdm は X11 前提のため、Wayland ネイティブな niri には不向き。
#   軽量で Wayland ネイティブな greetd + tuigreet に切り替え、
#   ログイン後に niri セッション (niri-session) が起動する構成とする。
{ pkgs, ... }:
{
  # niri 本体のインストールと Wayland セッションの登録
  programs.niri.enable = true;

  # Wayland コンポジタの描画に必要な GL ドライバ
  hardware.graphics.enable = true;

  # ディスプレイマネージャ: greetd + tuigreet
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --cmd ${pkgs.niri}/bin/niri-session";
        user = "greeter";
      };
    };
  };

  # XDG デスクトップポータル
  #  - xdg-desktop-portal-gnome: スクリーンキャスト用
  #    (niri は Mutter 互換の ScreenCast API を実装しているため gnome ポータル経由で動作する)
  #  - xdg-desktop-portal-gtk: ファイル選択ダイアログ等
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
    config.common.default = [ "gtk" "gnome" ];
  };

  # GUI アプリからの特権操作 (polkit) を有効化。
  # 認証エージェントは niri 起動時に立ち上げる (home/ai/niri-config.kdl)。
  security.polkit.enable = true;

  # サウンド: PipeWire (ALSA / PulseAudio 互換)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # 日本語表示用の CJK フォント
  fonts.packages = [ pkgs.noto-fonts-cjk-sans ];
}
