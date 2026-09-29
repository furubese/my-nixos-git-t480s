# 人間が編集するファイル（AI編集スコープ外。AI駆動の変更は modules/ai/** を参照）。
# 過去（AIがパッケージ名JSON配列だけを出力していた旧設計時代）に追加されたパッケージのうち、
# 以下は棚卸しの結果、旧設計の同じ不具合（パッケージだけ入って実際には有効化されない）の
# 痕跡として不要と判断し削除した：
#   - lightdm, lightdm-gtk-greeter: issue #10由来。niri+greetd+tuigreetへの切り替え
#     （modules/ai/niri-desktop.nix、issue #17）で完全に置き換えられ、有効化もされないまま
#     残っていた
#   - niri: issue #12由来。modules/ai/niri-desktop.nix の programs.niri.enable が
#     パッケージ自体も引き込むため、ここでの明示指定は冗長だった
{ pkgs, ... }:
{
  # openssh: sshd（services.openssh.enable、hosts/t480s/configuration.nixでコメントアウト中）
  # は意図的に無効のまま。ssh/scp等のクライアントコマンドとして使うのが目的で、
  # このマシンをSSHサーバーとして公開する意図はない。
  environment.systemPackages = with pkgs; [ git mise openssh openssl python3 ];
}
