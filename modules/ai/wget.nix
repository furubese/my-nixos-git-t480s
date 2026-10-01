# issue #48: wgetをシステムパッケージとして追加。
# modules/packages.nix（人間編集用・AI編集不可）と同じ environment.systemPackages 方式で、
# NixOSモジュールシステムのリストマージにより既存のパッケージ一覧に自動連結される。
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.wget ];
}
