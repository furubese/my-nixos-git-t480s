# issue #108 の回帰テスト。
# LazyVim 関連の設定 (modules/ai/lazyvim.nix / home/ai/lazyvim.nix) が、
# NixOS で起動時にエラーが出ない構成になっているかを静的に検証する:
# - LazyVim は Neovim 製のため neovim 本体が必要
# - パーサ取得・ビルドに必要なツール (gcc/gnumake/gnutar/unzip/curl) があること
# - mason の代替として LSP/フォーマッタ (lua-language-server/stylua/nil) と
#   検索系ツール (fd/ripgrep) を nixpkgs から導入していること
# - LazyVim の設定ファイル一式 (init.lua / config/lazy.lua / config 3点 /
#   plugins/nixos.lua) が ~/.config/nvim/ に配備されていること
# - mason.nvim が無効化されていること (FHS非対応バイナリの自動DL回避)
# - 補完エンジンが blink.cmp (ネイティブバイナリをDL) ではなく nvim-cmp に
#   なっていること (NixOS でのネイティブ .so ロード失敗回避)
{ lib, ... }:
let
  lazyvimModule = builtins.readFile ../../modules/ai/lazyvim.nix;
  lazyvimHome = builtins.readFile ../../home/ai/lazyvim.nix;
in
{
  assertions = [
    {
      assertion = lib.hasInfix "environment.systemPackages" lazyvimModule;
      message = "modules/ai/lazyvim.nix が environment.systemPackages を使っていない (issue #108)";
    }
    {
      assertion = lib.hasInfix "neovim" lazyvimModule;
      message = "modules/ai/lazyvim.nix に neovim がない: LazyVim は Neovim 製なので起動しない (issue #108)";
    }
    {
      assertion =
        lib.hasInfix "gcc" lazyvimModule
        && lib.hasInfix "gnumake" lazyvimModule
        && lib.hasInfix "gnutar" lazyvimModule
        && lib.hasInfix "unzip" lazyvimModule
        && lib.hasInfix "curl" lazyvimModule;
      message = "modules/ai/lazyvim.nix にビルド/取得ツール (gcc/gnumake/gnutar/unzip/curl) が不足: 初回起動時のプラグイン・パーサ取得が失敗する (issue #108)";
    }
    {
      assertion =
        lib.hasInfix "lua-language-server" lazyvimModule
        && lib.hasInfix "stylua" lazyvimModule
        && lib.hasInfix "nil" lazyvimModule
        && lib.hasInfix "fd" lazyvimModule
        && lib.hasInfix "ripgrep" lazyvimModule;
      message = "modules/ai/lazyvim.nix に mason 代替ツール (lua-language-server/stylua/nil/fd/ripgrep) が不足 (issue #108)";
    }
    {
      assertion =
        lib.hasInfix ''nvim/init.lua'' lazyvimHome
        && lib.hasInfix ''require("config.lazy")'' lazyvimHome
        && lib.hasInfix ''nvim/lua/config/lazy.lua'' lazyvimHome
        && lib.hasInfix ''"LazyVim/LazyVim"'' lazyvimHome;
      message = "home/ai/lazyvim.nix が LazyVim 本体の読み込み (init.lua / config/lazy.lua) を配備していない (issue #108)";
    }
    {
      assertion =
        lib.hasInfix "nvim/lua/config/options.lua" lazyvimHome
        && lib.hasInfix "nvim/lua/config/keymaps.lua" lazyvimHome
        && lib.hasInfix "nvim/lua/config/autocmds.lua" lazyvimHome;
      message = "home/ai/lazyvim.nix に LazyVim が起動時に読み込む config 3点 (options/keymaps/autocmds) の配備がない (issue #108)";
    }
    {
      assertion = lib.hasInfix "nvim/lua/plugins/nixos.lua" lazyvimHome;
      message = "home/ai/lazyvim.nix に NixOS 向けプラグイン設定 (lua/plugins/nixos.lua) がない (issue #108)";
    }
    {
      assertion =
        lib.hasInfix ''{ "mason-org/mason.nvim", enabled = false }'' lazyvimHome
        && lib.hasInfix ''{ "williamboman/mason.nvim", enabled = false }'' lazyvimHome;
      message = "home/ai/lazyvim.nix で mason.nvim が無効化されていない: NixOS で mason の自動DLがエラーになる (issue #108)";
    }
    {
      assertion = lib.hasInfix ''vim.g.lazyvim_cmp = "nvim-cmp"'' lazyvimHome;
      message = "home/ai/lazyvim.nix で補完エンジンが nvim-cmp に切り替えられていない: blink.cmp のネイティブバイナリが NixOS でロードエラーになる (issue #108)";
    }
    {
      assertion = !lib.hasInfix ''"saghen/blink.cmp"'' lazyvimHome;
      message = "home/ai/lazyvim.nix に blink.cmp のプラグイン指定が残っている (issue #108)";
    }
    {
      assertion = lib.hasInfix ''nil_ls = { mason = false }'' lazyvimHome;
      message = "home/ai/lazyvim.nix で nil_ls (Nix用LSP) が有効化されていない (issue #108)";
    }
  ];
}
