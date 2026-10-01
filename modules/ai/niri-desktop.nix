# niri + greetd(tuigreet) によるデスクトップ環境（issue #17で導入）。
# issue #59: nixpkgsのパッケージ再編成にともない、参照するパッケージ属性を
# 現行のトップレベル名へ更新した（X11系ライブラリは xorg 属性セット配下から、
# tuigreet は greetd パッケージ群のサブ属性から、それぞれ移動済み）。
{ pkgs, ... }:
{
  # niriウィンドウマネージャーを有効化。
  # niriパッケージ自体もここから自動で導入されるため、
  # modules/packages.nix 側での個別指定は不要。
  programs.niri.enable = true;

  # ログインマネージャー: greetd 上で tuigreet（ターミナルUIグリーター）を
  # 実行し、niri セッションを起動する。tuigreet は nixpkgs のトップレベル
  # 属性（pkgs.tuigreet）へ移動済みのため、そちらを参照する。
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd niri-session";
        user = "fse";
      };
    };
  };

  # X11/XWayland アプリケーション用のクライアントライブラリ。
  # nixpkgs の再編成で xorg 属性セット配下からトップレベルの小文字名へ
  # 移動しているため、現行名で参照する。
  environment.systemPackages = with pkgs; [
    libx11
    libxcursor
    libxi
    libxrandr
  ];
}
