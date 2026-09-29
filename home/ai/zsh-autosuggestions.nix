# issue #29: zsh-autosuggestions を導入する
#
# home/fse.nix（人間管理・編集不可）では oh-my-zsh のテーマと git プラグインのみが
# 設定されているため、AI編集スコープの home/ai/ 配下に Home Manager モジュールを
# 追加して programs.zsh に統合する（HMの属性合成により既存のoh-my-zsh設定と共存）。
#
# programs.zsh.autosuggestion.enable は pkgs.zsh-autosuggestions のインストールと
# sourcing を自動で行うため、oh-my-zsh のカスタムプラグインとして手動設置する
# 必要はない。なお旧オプション programs.zsh.enableAutosuggestions は 24.05 で
# 非推奨になったため、HM 26.05 相当では autosuggestion.enable を使うのが正しい。
{ ... }:
{
  programs.zsh.autosuggestion.enable = true;
}
