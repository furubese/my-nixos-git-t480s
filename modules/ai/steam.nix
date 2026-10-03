# issue #74: steam起動時の "Check your DISPLAY environment variable" エラー対策。
# このホストは niri (Waylandコンポジタ) で動作しており、X11アプリであるsteamは
# Xwayland 相当のレイヤーがないと DISPLAY を見つけられず起動に失敗する。
# xwayland-satellite を導入し、ユーザーセッションで起動して :12 などの
# X ディスプレイを提供することで、niri 上でもX11アプリが動作するようにする。
{ pkgs, ... }:
{
  # steam本体と依存の有効化（32bitライブラリ等も programs.steam が面倒を見る）
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = false; # サーバー公開の意図はないため防火壁は開けない
    dedicatedServer.openFirewall = false;
  };

  # niri は組み込みの Xwayland サポートを持たないため、xwayland-satellite で
  # X サーバーをエミュレートし、X11 アプリ (steam等) に DISPLAY を提供する。
  environment.systemPackages = with pkgs; [ xwayland-satellite ];

  # ユーザーセッションで xwayland-satellite を起動し、そのXディスプレイを
  # セッション全体の DISPLAY として export する。
  systemd.user.services.xwayland-satellite = {
    description = "Xwayland-satellite (X11 compatibility layer for niri)";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite";
      Restart = "on-failure";
    };
  };

  # xwayland-satellite が起動するXディスプレイ (既定では :0 が埋まっている場合
  # 次の番号) を環境変数で指定し、steam等のX11アプリが参照できるようにする。
  # systemd user セッション全体に伝えるため、環境変数を設定する。
  environment.sessionVariables = {
    DISPLAY = ":12";
  };
}
