# AI-EDITABLE: パッケージ追加はこのリスト内のみで行うこと
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ git lightdm lightdm-gtk-greeter mise niri openssh openssl python3 ];
}
