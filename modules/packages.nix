# AI-EDITABLE: パッケージ追加はこのリスト内のみで行うこと
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ git ];
}
