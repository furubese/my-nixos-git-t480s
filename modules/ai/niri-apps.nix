# niri設定(home/ai/niri.kdl)からspawnするアプリケーション。
#
# システムプロファイルに入れる理由: greetd起動のniriセッションでは
# ユーザープロファイル(~/.nix-profile/bin)がPATHに載らないため、niriから
# spawnできる状態にしておく必要がある。
# （Noctalia本体は modules/ai/noctalia.nix で同様にシステム側に入れている）
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    foot # Waylandターミナル（niri設定: Mod+T）
    fuzzel # アプリランチャー（niri設定: Mod+D）
  ];
}
