# issue #43: zellijをtmux互換キーバインドで導入するHome Manager設定。
#
# - zellij本体は programs.zellij.enable でユーザー環境に導入する
# - キーバインドを含む設定本体は隣の zellij-config.kdl を
#   ~/.config/zellij/config.kdl としてそのまま配置する
#
# programs.zellij.settings / extraConfig を空にしておけばHome Managerは
# config.kdl を生成しないため、下の xdg.configFile との競合は起きない。
# キーバインドのように同じノード名(bind)が繰り返し現れるKDLは
# settings の属性セットでは表現できないため、KDLファイルを直接配置する。
{ ... }:
{
  programs.zellij.enable = true;

  xdg.configFile."zellij/config.kdl".source = ./zellij-config.kdl;
}
