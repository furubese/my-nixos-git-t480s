# niriのユーザー側設定（Home Managerモジュール）
#
# - ~/.config/niri/config.kdl を home/ai/niri-config.kdl から配置する
# - カーソルテーマ（catppuccin frappe green / 32px）をGTKアプリ等にも反映する
{ pkgs, lib, ... }:
{
  xdg.configFile."niri/config.kdl".source = ./niri-config.kdl;

  # カーソルテーマ。niri設定（cursor.xcursor-theme）と同一のものを指定。
  # nixpkgsにcatppuccin-cursors.frappeGreenが存在しない場合はスキップされ、
  # niri/GTKともデフォルトテーマへフォールバックする。
  home.pointerCursor = lib.mkIf (pkgs ? catppuccin-cursors.frappeGreen) {
    package = pkgs.catppuccin-cursors.frappeGreen;
    name = "catppuccin-frappe-green-cursors";
    size = 32;
    gtk.enable = true;
  };

  # Waylandネイティブアプリ向けにカーソルテーマを明示
  home.sessionVariables = {
    XCURSOR_THEME = "catppuccin-frappe-green-cursors";
    XCURSOR_SIZE = "32";
  };
}
