# issue #63: niriでWin+Dのfuzzel、Win+Tのalacrittyが使えるようにする。
#
# 方針:
# niriは ~/.config/niri/config.kdl が存在しない場合、内蔵のデフォルト設定で起動し、
# そのデフォルトキーバインドにはすでに
#   Mod+D { spawn "fuzzel"; }    (アプリケーションランチャー)
#   Mod+T { spawn "alacritty"; } (ターミナル)
# が含まれている(ModはSuper/Winキー)。
# つまりWin+Dでfuzzelが起動しないのはキーバインドの問題ではなく、spawn先の
# fuzzel/alacrittyコマンドがPATH上に存在しない(パッケージが入っていない)ことが原因。
# そのためniri側の設定には手を入れず、パッケージを追加するだけで
# Win+D / Win+T がそのまま機能するようになる。
#
# greetdから起動されるniriセッションでも確実にPATHが通るよう、
# ユーザー個別プロファイルではなくenvironment.systemPackages(システムプロファイル)に入れる。
#
# またfuzzel/alacrittyは文字描画にfontconfigのシステムフォントを使うため、
# フォントが1つも無いと起動しても文字が表示できない。ja_JP環境なので
# Latinと日本語(CJK)をカバーするNotoを合わせて導入する。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    fuzzel    # Waylandネイティブなアプリランチャー (niriデフォルト: Mod+D)
    alacritty # Wayland対応ターミナル (niriデフォルト: Mod+T)
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans # 日本語グリフ用
  ];
}
