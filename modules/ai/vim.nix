# issue #47: vimをインストールする
#
# modules/packages.nix は人間編集用のためAI編集スコープ外なので、
# modules/ai/ 配下にNixOSモジュールとして追加する。
# このディレクトリは hosts/t480s/configuration.nix から自動importされるため、
# このファイルを置くだけで t480s に vim が入る。
#
# vim は environment.systemPackages に追加するだけで即座に使える
# （lightdm等と違い、有効化のための services.* オプションは存在しない。
# 過去の「パッケージだけ入れて実際には有効化されない」旧設計の問題はここには該当しない）。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ vim ];
}
