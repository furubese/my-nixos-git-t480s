# issue #63: niriでWin+Dのfuzzelが使えるようにする。
#
# review対応: 旧 modules/ai/fuzzel-alacritty.nix を fuzzel / alacritty の
# 別々のモジュールへ分割したうちの、ランチャー(fuzzel)担当。
# ターミナル(alacritty)担当は modules/ai/alacritty.nix。
#
# 方針:
# niriは ~/.config/niri/config.kdl が存在しない場合、内蔵のデフォルト設定で起動し、
# そのデフォルトキーバインドにはすでに
#   Mod+D { spawn "fuzzel"; } (アプリケーションランチャー)
# が含まれている(ModはSuper/Winキー)。
# つまりWin+Dでfuzzelが起動しないのはキーバインドの問題ではなく、spawn先の
# fuzzelコマンドがPATH上に存在しない(パッケージが入っていない)ことが原因。
# そのためniri側の設定には手を入れず、パッケージを追加するだけで
# Win+D がそのまま機能するようになる。
#
# greetdから起動されるniriセッションでも確実にPATHが通るよう、
# ユーザー個別プロファイルではなくenvironment.systemPackages(システムプロファイル)に入れる。
#
# またfuzzelは文字描画にfontconfigのシステムフォントを使うため、
# フォントが1つも無いと起動しても文字が表示できない。ja_JP環境なので
# Latinと日本語(CJK)をカバーするNotoを合わせて導入する。
# modules/ai/alacritty.nix 側でも同じフォントを宣言しているが、
# fonts.packages はリスト結合でマージされ同一パッケージの重複は無害なため、
# 各モジュールが単独で完結するよう必要なフォントは各自で宣言する。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    fuzzel # Waylandネイティブなアプリランチャー (niriデフォルト: Mod+D)
  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans # 日本語グリフ用
  ];
}
