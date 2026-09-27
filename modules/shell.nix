# デフォルトシェルをzshにするためのシステム側設定。
# ユーザーごとのzsh/oh-my-zshの中身（テーマ・プラグイン等）は home/fse.nix（Home Manager）側で管理する。
{ pkgs, ... }:
{
  # /etc/shells にzshを登録し、chsh等で選択可能にする
  programs.zsh.enable = true;

  # fseのログインシェルをzshにする
  users.users.fse.shell = pkgs.zsh;
}
