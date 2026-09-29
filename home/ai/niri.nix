# niri + Noctalia のユーザー側設定 (Home Manager)。
# システム側 (niri 本体・セッション登録・ディスプレイマネージャ) は
# modules/ai/niri-desktop.nix を参照。
{ pkgs, ... }:
{
  # niri セッション内で使うユーザー用ツール。
  # 注: modules/packages.nix (システムパッケージリスト) は編集不可のため、
  # ユーザープロファイル (home.packages) 側で導入する。
  home.packages = with pkgs; [
    # ターミナル (Wayland ネイティブ)
    foot
    # アプリケーションランチャー (Wayland ネイティブ)
    fuzzel
    # polkit 認証エージェント (GUI の特権昇格ダイアログ)
    lxqt.lxqt-policykit
    # Noctalia のランタイム (qs コマンド)
    quickshell
    # Noctalia: バー / 通知 / ランチャー / OSD 等を提供するデスクトップシェル
    noctalia-shell
    # メディア操作 CLI (Noctalia のメディアウィジェット・メディアキー用)
    playerctl
    # wpctl CLI (音量キー用)
    wireplumber
    # 輝度キー用 CLI
    brightnessctl
  ];

  # niri の設定ファイルを配置する
  xdg.configFile."niri/config.kdl".source = ./niri-config.kdl;
}
