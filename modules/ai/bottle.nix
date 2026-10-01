# Bottles（Wineプレフィックスマネージャー）の導入。
#
# issue #62: nixpkgsでX11ライブラリの属性名が変更され、xorg.libX11 などの
# 旧 xorg.* 属性はトップレベルの小文字名（libx11 など）へ移行した。
# これに合わせて、パッケージ参照をすべて新名称に更新した（構成の変更はなし）。
#
# NixOSはFHSレイアウトではないため、Wineランナーが実行時に必要とする
# X11ライブラリは明示的に導入しておく。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    bottles

    # Wineが必要とするX11ライブラリ（旧 xorg.libX* → 新 libx*）
    libx11
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxinerama
    libxrandr
    libxrender
    libxtst
    libxxf86vm
  ];
}
