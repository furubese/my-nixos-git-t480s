# noctalia設定のデプロイ (issue #76)
# 設定本体は home/ai/noctalia.json → ~/.config/noctalia/config.json
{ lib, ... }:
{
  xdg.configFile."noctalia/config.json".source = ./noctalia.json;

  # noctalia のアセット置き場 (niri.kdl の NOCTALIA_ASSETS_DIR) をあらかじめ用意
  home.activation.createNoctaliaAssetsDir =
    lib.hm.dag.entryAnywhere "mkdir -p $HOME/.local/share/noctalia-assets";
}
