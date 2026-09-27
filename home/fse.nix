{ ... }:
{
  home.username = "fse";
  home.homeDirectory = "/home/fse";
  # home-manager release-26.05 に対応する値。nix flake check で列挙型エラーが出た場合はHMが
  # サポートする最も近いバージョンに調整すること
  home.stateVersion = "26.05";
}
