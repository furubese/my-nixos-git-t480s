# noctalia（Quickshellベースのデスクトップシェル）のユーザー側設定（Home Managerモジュール）
#
# ~/.config/noctalia/settings.toml を home/ai/noctalia-settings.toml から配置する。
#
# 注意: noctalia本体はnixpkgsに存在しない（issue #21時点）。本体の導入には
# flake.nixへのinput追加（例: github:noctalia-dev/noctalia-shell）が必要で、
# flake.nixは本PRの編集スコープ外のため、このPRでは設定ファイルの配備のみを行う。
# modules/ai/niri-desktop.nix に「pkgsにnoctaliaがあれば導入」のガードがあるため、
# input追加 + overlay後に本体は自動で入る。
{ ... }:
{
  xdg.configFile."noctalia/settings.toml".source = ./noctalia-settings.toml;
}
