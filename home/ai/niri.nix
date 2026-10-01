# niri設定ファイルの配置（Home Manager側）。
#
# 実体は home/ai/niri.kdl で、~/.config/niri/config.kdl として配置される。
# niriはユーザー設定をシステム側設定(/etc/xdg)より優先して読むため、
# 旧来のシステム側設定が残っていても常にこの設定が使われる。
#
# issue #64: Noctalia（C++実装の単体バイナリ）はこのKDL内のspawn-at-startupから
# 直接起動する（旧Quickshell(QML)版の中間ツール経由の起動は廃止）。
{ lib, ... }:
{
  # niri設定はこのモジュールが所有する。他にniri設定を配置するモジュールが
  # 残っていてもこの設定を優先させる。
  home.file.".config/niri/config.kdl".source = lib.mkForce ./niri.kdl;
}
