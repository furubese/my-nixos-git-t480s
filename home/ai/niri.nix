# niri設定のデプロイ (issue #76)
# 設定本体は home/ai/niri.kdl → ~/.config/niri/config.kdl
{ lib, ... }:
{
  xdg.configFile."niri/config.kdl".source = ./niri.kdl;

  # スクリーンショット保存先 (niri.kdl の screenshot-path) をあらかじめ用意
  home.activation.createScreenshotDir =
    lib.hm.dag.entryAnywhere "mkdir -p $HOME/Pictures/Screenshots";
}
