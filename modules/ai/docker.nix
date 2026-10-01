# issue #46: Dockerを導入する
#
# modules/packages.nix の棚卸しコメントにある「パッケージだけ入って実際には
# 有効化されない」旧パターン（issue #10/#12の反省）を繰り返さないよう、
# environment.systemPackages に docker を足すのではなく、NixOS標準の
# Dockerモジュールでデーモンごと有効化する。これにより dockerd の
# systemdサービス有効化・docker CLIの導入・コンテナ用ネットワーク設定が
# すべて宣言的に行われる。
{ pkgs, ... }:
{
  virtualisation.docker.enable = true;

  # fseがsudoなしでdockerコマンドを使えるようdockerグループに追加。
  # extraGroups はリスト結合でマージされるため、hosts/t480s/configuration.nix の
  # networkmanager/wheel は上書きされない。
  # 注意: dockerグループは事実上root相当の権限を伴う。また反映には再ログインが必要。
  users.users.fse.extraGroups = [ "docker" ];
}
