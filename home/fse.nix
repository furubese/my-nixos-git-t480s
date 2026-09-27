{ ... }:
{
  home.username = "fse";
  home.homeDirectory = "/home/fse";
  # home-manager release-26.05 に対応する値。nix flake check で列挙型エラーが出た場合はHMが
  # サポートする最も近いバージョンに調整すること
  home.stateVersion = "26.05";

  # zsh + oh-my-zsh をHome Manager側で宣言的に管理する。
  # ログインシェル自体の切り替えは modules/shell.nix（システム側）で行う。
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" ];
    };
    # 好みに応じて追記していく場所（alias等）
    shellAliases = { };
  };
}
