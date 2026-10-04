# issue #108: LazyVim (Neovim向けプラグインディストリビューション) を導入する
#
# LazyVim は Neovim 上で動作するため、エディタ本体として neovim を導入する
# (issue #47 の素の vim はそのまま残す。設定ファイルの配備は home/ai/lazyvim.nix 側)。
#
# LazyVim は初回起動時に lazy.nvim がプラグイン一式を git clone し、
# nvim-treesitter のパーサをローカルコンパイルする。通常のLinuxなら何も要らないが、
# NixOSでは以下をシステム側で用意しておく必要がある:
#   - gcc / gnumake / gnutar / unzip / curl:
#     パーサのコンパイルとプラグイン・アーカイブの取得・展開に必要。
#     nixpkgs の gcc ラッパは生成物に適切な RPATH を付けるため、
#     ビルドしたパーサが Neovim から正常に読み込まれる。
#     (git は modules/packages.nix で、wget は modules/ai/wget.nix で導入済み)
#   - lua-language-server / stylua:
#     LazyVim 既定の Lua 開発環境 (LSP + フォーマッタ)。LazyVim 既定では
#     mason.nvim がこれらを自動DLするが、NixOS には FHS パスがなくDLした
#     バイナリが動かないため、mason は home/ai/lazyvim.nix 側で無効化し、
#     nixpkgs から提供する (LazyVim を NixOS で使う際の定番の調整)。
#   - nil: Nix言語用のLSPサーバー (.nix ファイル編集用。nvim側で nil_ls として有効化)
#   - fd / ripgrep / lazygit: LazyVim 標準の検索 (snacks.picker 等) と
#     gitフロントエンドが使う外部コマンド
#   - wl-clipboard: niri (Wayland) 環境でのクリップボード連携
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    neovim
    gcc
    gnumake
    gnutar
    unzip
    curl
    lua-language-server
    stylua
    nil
    fd
    ripgrep
    lazygit
    wl-clipboard
  ];
}
