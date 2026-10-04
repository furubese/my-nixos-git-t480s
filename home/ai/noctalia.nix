# noctalia設定のデプロイ (issue #76, issue #101)
# 設定本体は home/ai/noctalia.toml → ~/.config/noctalia/config.toml
#
# 現行のnoctalia (5.x, C++実装) は ~/.config/noctalia/ 配下の *.toml を
# 読み込むため、TOMLで配置する (旧JSON形式 config.json は読み込まれない
# ため廃止した)。
# GUIで変更した設定は ~/.local/state/noctalia/settings.toml 側に保存され、
# このファイルより優先される。
#
# 旧 spawn 用のアセット置き場 (~/.local/share/noctalia-assets) は廃止:
# NOCTALIA_ASSETS_DIR はアセットバンドル全体(emoji/フォント/テンプレート等)
# を差し替えるための変数で、空ディレクトリを渡すとnoctalia起動時に
# 警告が出てパッケージ同梱のものへフォールバックされるだけのため。
{ ... }:
{
  xdg.configFile."noctalia/config.toml".source = ./noctalia.toml;
}
