# issue #25: VSCODEをインストールしてほしい
#
# pkgs.vscode（Microsoft公式ビルド）は unfree ライセンスだが、
# hosts/t480s/configuration.nix の nixpkgs.config.allowUnfree = true が
# 既に設定されているため、追加設定なしで利用できる。
#
# 備考:
# - modules/packages.nix は人間編集用（AI編集スコープ外）のため、
#   同ファイルのコメント方針（AI駆動の変更は modules/ai/**）に従い、
#   この個別ファイルとして追加した。
# - 一部の拡張機能（言語サーバー等）がFHS環境を前提として動かない場合は
#   pkgs.vscode.fhs への差し替えを検討するとよい。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ vscode ];
}
