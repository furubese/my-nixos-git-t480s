# issue #71: jq をインストールする
#
# modules/packages.nix は人間編集用ファイルのため AI 編集スコープ外。
# AI 駆動の変更は modules/ai/ 配下に置く規約なので、ここに NixOS モジュールとして追加する。
# modules/ai/*.nix は hosts 側（../../modules/ai）から自動 import されるため、
# このファイルを置くだけでシステムプロファイルに jq が入る。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ jq ];
}
