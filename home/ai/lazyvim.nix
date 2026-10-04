# issue #108: LazyVim の設定ファイル (~/.config/nvim/**) を配備する Home Manager モジュール
#
# LazyVim は Neovim 向けプラグインディストリビューションで、設定は
# ~/.config/nvim/ に置かれた Lua ファイル群として管理される
# (公式 starter と同じ構成: init.lua / lua/config/* / lua/plugins/*)。
# neovim 本体と補助ツール類は NixOS 側の modules/ai/lazyvim.nix で導入する。
#
# NixOS でエラーなく LazyVim を起動するための調整 (LazyVim 既定からの差分):
#  1. mason.nvim / mason-lspconfig.nvim を無効化
#     LazyVim 既定は mason が LSPサーバー等を ~/.local/share/nvim/mason へ
#     自動DLするが、NixOS には FHS パス (/lib64/ld-linux など) が無いため
#     ダウンロードした実行バイナリが動かず、起動時にエラー通知が出る。
#     LSPサーバー/フォーマッタは代わりに nixpkgs から導入する
#     (modules/ai/lazyvim.nix の lua-language-server / stylua / nil)。
#  2. 補完エンジンを nvim-cmp に切替 (vim.g.lazyvim_cmp = "nvim-cmp")
#     LazyVim 14 以降の既定補完エンジン blink.cmp は事前ビルドされた
#     Rust製ネイティブバイナリ (libblink_cmp.so) をダウンロードして使うが、
#     これも NixOS ではロードに失敗しエラーになるため、純Lua実装の nvim-cmp へ
#     LazyVim 公式の切替設定で変更する。
#  3. treesitter のパーサはローカルコンパイル
#     LazyVim 既定のパーサ一覧は起動時に C コンパイラでビルドされる。
#     nixpkgs の gcc (modules/ai/lazyvim.nix で導入) は RPATH 付きでビルドする
#     ため NixOS でも正常動作する。
#
# なお lazy.nvim / LazyVim 本体とプラグイン一式は、初回起動時に
# ~/.local/share/nvim/lazy へ git clone される (LazyVim 標準の挙動のため、
# 初回起動にはネットワーク接続と時間が必要)。2回目以降は
# ~/.config/nvim/lazy-lock.json でバージョンが固定される。
{ ... }:
{
  # LazyVim のエントリポイント (公式 starter と同じ)
  xdg.configFile."nvim/init.lua".text = ''
    -- LazyVim のエントリポイント (公式 starter と同じ1行)
    require("config.lazy")
  '';

  # lazy.nvim の bootstrap と LazyVim 本体/プラグインの読み込み
  # (公式 starter の lua/config/lazy.lua 相当 + NixOS 向けの調整)
  xdg.configFile."nvim/lua/config/lazy.lua".text = ''
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not (vim.uv or vim.loop).fs_stat(lazypath) then
      -- bootstrap lazy.nvim (git は modules/packages.nix で導入済み)
      local lazyrepo = "https://github.com/folke/lazy.nvim.git"
      local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
      if vim.v.shell_error ~= 0 then
        vim.api.nvim_echo({
          { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
          { out, "WarningMsg" },
          { "\nPress any key to exit..." },
        }, true, {})
        vim.fn.getchar()
        os.exit(1)
      end
    end
    vim.opt.rtp:prepend(lazypath)

    -- NixOS 向け調整: 補完エンジンを nvim-cmp に切り替える。
    -- blink.cmp は事前ビルドのネイティブバイナリ (libblink_cmp.so) を
    -- ダウンロードして使うが、NixOS ではロードに失敗してエラーになるため、
    -- 純Lua実装の nvim-cmp を使う (lazy.setup より前に設定する必要がある)
    vim.g.lazyvim_cmp = "nvim-cmp"

    -- configure lazy.nvim
    require("lazy").setup({
      spec = {
        -- add LazyVim and import its plugins
        { "LazyVim/LazyVim", import = "lazyvim.plugins" },
        -- import any plugins and/or extras modules here
        { import = "plugins" },
      },
      defaults = {
        lazy = false,
      },
      install = { colorscheme = { "habamax" } },
      -- automatically check for plugin updates
      checker = { enabled = true, notify = false },
      performance = {
        rtp = {
          -- disable some builtin vim plugins to improve startup
          disabled_plugins = {
            "gzip",
            "matchit",
            "matchparen",
            "netrwPlugin",
            "tarPlugin",
            "tohtml",
            "tutor",
            "zipPlugin",
          },
        },
      },
    })
  '';

  # LazyVim 既定値のオプション/キーマップ/autocmd は LazyVim 本体
  # (lua/lazyvim/config/*.lua) で定義済みのため、上書き不要のファイルを置く
  # (LazyVim はこれらのファイルを起動時に読み込む仕様)
  xdg.configFile."nvim/lua/config/options.lua".text = ''
    -- 追加したいオプションがあればここに書く
    -- (LazyVim 既定のオプションは LazyVim 本体の lua/lazyvim/config/options.lua で定義済み)
  '';

  xdg.configFile."nvim/lua/config/keymaps.lua".text = ''
    -- 追加したいキーマップがあればここに書く
    -- (LazyVim 既定のキーマップは LazyVim 本体の lua/lazyvim/config/keymaps.lua で定義済み)
  '';

  xdg.configFile."nvim/lua/config/autocmds.lua".text = ''
    -- 追加したい autocmd があればここに書く
    -- (LazyVim 既定の autocmd は LazyVim 本体の lua/lazyvim/config/autocmds.lua で定義済み)
  '';

  # NixOS 向けのプラグイン設定 (mason 無効化 + nixpkgs 導入のLSPを使用)
  xdg.configFile."nvim/lua/plugins/nixos.lua".text = ''
    -- NixOS 向けの調整 (issue #108)
    --
    -- LazyVim 既定は mason.nvim が LSPサーバー/ツールを
    -- ~/.local/share/nvim/mason へ自動ダウンロードするが、NixOS は FHS パスを
    -- 持たないためダウンロードした実行バイナリが動かず、起動時にエラー通知が出る。
    -- そのため mason を無効化し、必要なツールは nixpkgs (modules/ai/lazyvim.nix)
    -- から導入したものを PATH 経由で使う。
    return {
      -- mason.nvim は 2025年に williamboman から mason-org へ移管された。
      -- LazyVim が参照する名の新旧両方を無効化しておく
      { "mason-org/mason.nvim", enabled = false },
      { "mason-org/mason-lspconfig.nvim", enabled = false },
      { "williamboman/mason.nvim", enabled = false },
      { "williamboman/mason-lspconfig.nvim", enabled = false },

      -- LSPサーバーは nixpkgs から導入したものを使用する:
      --   lua-language-server: LazyVim 既定の lua_ls
      --   nil: Nix言語用LSP (nil_ls として有効化)
      -- (mason = false で mason 側の自動インストール対象から外す)
      {
        "neovim/nvim-lspconfig",
        opts = {
          servers = {
            lua_ls = { mason = false },
            nil_ls = { mason = false },
          },
        },
      },
    }
  '';

  # Lua フォーマッタ stylua の設定 (LazyVim starter と同じ内容)
  xdg.configFile."nvim/stylua.toml".text = ''
    indent_type = "Spaces"
    indent_width = 2
    column_width = 120
  '';
}
