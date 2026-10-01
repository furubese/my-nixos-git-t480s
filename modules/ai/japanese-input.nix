# 日本語入力（fcitx5 + Mozc）のシステム側設定（issue #26）。
#
# i18n.inputMethod で fcitx5 を有効化すると、NixOSが自動で行うこと：
#   - fcitx5 本体に加え GTK/Qt アプリ用フロントエンド（fcitx5-gtk / fcitx5-qt）を
#     含む fcitx5-with-addons をシステムプロファイルへ導入する
#   - GTK_IM_MODULE / QT_IM_MODULE / XMODIFIERS 等の環境変数を全セッションに
#     設定し、アプリケーションがfcitx5を入力メソッドとして使うようになる
#   - XDG autostart による自動起動（これを処理するセッション向け。
#     niri は XDG autostart を処理しないため、デーモン起動は
#     home/ai/japanese-input.nix の systemd user service 側で行う）
#
# 入力メソッドの切り替え（英数直接入力 ↔ Mozc）は fcitx5 の既定の
# トリガーキー（Ctrl+Space または 半角/全角）で行う。
{ pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    # Mozc: かな漢字変換エンジン
    fcitx5.addons = [ pkgs.fcitx5-mozc ];
  };

  # fcitx5 のGUI設定ツール（トリガーキーの変更、Mozcの設定等）
  environment.systemPackages = [ pkgs.fcitx5-configtool ];

  # 入力した日本語を画面に表示するためのCJKフォント。
  # これがないと変換はできても文字が豆腐（□）になる
  fonts.packages = [ pkgs.noto-fonts-cjk-sans ];

  # Noto Sans CJK は中韓台の字形も含むため、日本語テキストには日本語字形 (JP) が
  # 使われるよう、fontconfig の既定フォントを指定しておく。
  # 注: fonts.fontconfig.defaultFonts に japanese のような言語別のキーは存在しない
  # ため、実際に定義されている sansSerif / monospace で指定する。
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "DejaVu Sans" "Noto Sans CJK JP" ];
    monospace = [ "DejaVu Sans Mono" "Noto Sans Mono CJK JP" ];
  };
}