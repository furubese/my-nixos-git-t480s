# niri + noctalia デスクトップ環境 (issue #76, #101)
# 普段使いの Fedora (niri + noctalia) 環境に寄せた構成。
# - niri本体とWaylandセッションは programs.niri.enable が提供
# - ログインは greetd + tuigreet (issue #17 の構成を維持)
# - noctalia は niri設定 (home/ai/niri.kdl) の spawn-at-startup から起動
# - noctalia本体のインストールは modules/ai/noctalia.nix が担当
#   (nixpkgsにパッケージが無い場合に警告だけ出す作りのため、ここでは
#   二重に追加しない)
# - niri / noctalia の設定ファイル本体は home/ai/niri.nix, home/ai/noctalia.nix がデプロイ
{ pkgs, ... }:

let
  # カーソルテーマ (niri.kdl の cursor.xcursor-theme で参照)。
  # nixpkgs の catppuccin-cursors は出力(output)ごとにフレーバーが分かれており、
  # frappeGreen 出力がテーマ「catppuccin-frappe-green-cursors」を提供する。
  # なければスキップする (存在チェックによりビルドは壊さない)。
  catppuccinCursors =
    if (pkgs ? catppuccin-cursors) && (pkgs.catppuccin-cursors ? frappeGreen)
    then [ pkgs.catppuccin-cursors.frappeGreen ]
    else [ ];
in
{
  # Waylandコンポジタ
  programs.niri.enable = true;

  # niri のレンダリングに必要
  hardware.graphics.enable = true;

  # ログインマネージャ: greetd + tuigreet → niri セッション
  # 注: 旧 pkgs.greetd.tuigreet は nixpkgs で pkgs.tuigreet にリネームされた
  # (issue #95 の評価警告対応)。
  services.greetd = {
    enable = true;
    settings.default_session.command =
      "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd ${pkgs.niri}/bin/niri";
  };

  # 音声: PipeWire + WirePlumber (wpctl のバックエンド)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # polkit (noctalia の polkit_agent が使用)
  security.polkit.enable = true;

  # XDGポータル (ファイルダイアログ・スクリーンキャスト等)
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  # 日本語デスクトップ用フォント
  # 注: 旧 noto-fonts-emoji は 2025-10-27 の nixpkgs 変更で noto-fonts-color-emoji
  # へリネームされたため、現行の属性名を参照する。
  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
  ];

  environment.systemPackages = with pkgs; [
    # 注: noctalia本体は modules/ai/noctalia.nix がシステムプロファイルに入れる
    # (niri.kdl の spawn-at-startup "noctalia" から参照される)
    alacritty # ターミナル (niri.kdl の Mod+T)
    firefox # ドックにpinするブラウザ (home/ai/noctalia.toml の dock.pinned)
    brightnessctl # 輝度キー (niri.kdl のbinds)
    playerctl # メディアキー (同上)
    wireplumber # wpctl (音量キー)
  ] ++ catppuccinCursors;

  # XWayland / Qt アプリにもカーソルテーマを反映
  environment.sessionVariables = {
    XCURSOR_THEME = "catppuccin-frappe-green-cursors";
    XCURSOR_SIZE = "32";
  };
}
