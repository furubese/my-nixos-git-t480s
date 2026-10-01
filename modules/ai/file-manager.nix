# issue #33: ファイルマネージャの整備
#
# nautilus / dolphin / nemo を比較検討し、nautilus (GNOME Files) を採用した。
# 理由:
#   - GTK4/libadwaita による Wayland ネイティブ実装で、niri デスクトップ
#     (modules/ai/niri-desktop.nix) と技術スタックが一致し、依存も最小
#   - dolphin は Plasma/KDE 向けの Qt アプリで KDE Frameworks を大きく
#     引き込むため、niri 環境ではスタックが重複して過剰
#   - nemo は Nautilus 3.x 系のフォークで Cinnamon/xapp 系の依存が増え、
#     Wayland 対応の開発リソースも GNOME 本流に比べて劣る
#
# なお nautilus はパッケージを入れるだけではゴミ箱・リムーバブルメディア・
# ネットワーク場所 (sftp:// 等) が動かないため、gvfs/udisks2 を併せて
# 有効化している。
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nautilus
  ];

  # nautilus の各種設定 (表示モード・並び順等) を永続化する dconf の DBus サービス
  programs.dconf.enable = true;

  # ゴミ箱・リムーバブルメディア・ネットワーク場所のサポート (GVfs)
  services.gvfs.enable = true;

  # USBメモリ等のブロックデバイスの検出とマウント (udisks2)
  services.udisks2.enable = true;

  # nautilus 上でスペースキーを押したときのクイックプレビュー (Sushi)
  services.gnome.sushi.enable = true;

  # 「フォルダを開く」操作の既定アプリを nautilus に固定する
  xdg.mime.defaultApplications."inode/directory" = [ "org.gnome.Nautilus.desktop" ];
}
