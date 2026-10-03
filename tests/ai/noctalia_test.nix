# issue #64 の回帰テスト。
#
# niri設定(home/ai/niri.kdl)がNoctalia（C++版・単体バイナリ）を正しく起動するかを
# 静的に検証する:
# - spawn-at-startup "noctalia" が存在すること
# - 旧Quickshell(QML)版の中間ツール経由の起動指定が残っていないこと
{ lib, ... }:
let
  niriConfig = builtins.readFile ../../home/ai/niri.kdl;
in
{
  assertions = [
    {
      assertion = lib.hasInfix ''spawn-at-startup "noctalia"'' niriConfig;
      message = ''niri設定(home/ai/niri.kdl)に spawn-at-startup "noctalia" がない: Noctaliaが起動しない (issue #64)'';
    }
    {
      assertion =
        !lib.hasInfix "quickshell" niriConfig
        && !lib.hasInfix ''spawn-at-startup "qs"'' niriConfig;
      message = "niri設定に旧Quickshell版Noctaliaの起動指定が残っている (issue #64)";
    }
  ];
}
