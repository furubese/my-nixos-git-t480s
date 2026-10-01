# issue #35: バイナリ解析用 devshell の mkShell 定義。
#
# 【注意】このファイル単体では何も発動しない。flake.nix の devShells 出力への接続が
# 必要だが、flake.nix はAI編集スコープ外（人間編集ファイル）のため、人間による
# flake.nix への追記を想定している:
#
#   # flake.nix の outputs 内（例）
#   devShells.x86_64-linux.binary-analysis =
#     import ./tests/ai/binary-analysis-devshell.nix {
#       pkgs = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
#     };
#
# 接続後は `nix develop .#binary-analysis` で利用できる。
# 接続までの間は modules/ai/binary-analysis-devshell.nix が提供する `bin-analysis`
# コマンドで同じツール群が利用できる。
# ツール一覧は modules/ai/binary-analysis-devshell.nix と同期すること。
{ pkgs ? import <nixpkgs> { config.allowUnfree = true; } }:
pkgs.mkShell {
  name = "binary-analysis";
  # ghidra は unfree 扱いのため、呼び出し側の pkgs は allowUnfree を有効化すること
  # （デフォルト引数の <nixpkgs> は NIX_PATH 依存。flakeからは必ずpkgsを明示渡しする）。
  packages = with pkgs; [
    gdb
    radare2
    ghidra
    strace
    ltrace
    binutils
    file
    patchelf
    valgrind
    binwalk
    nasm
  ];
  shellHook = ''
    echo "[binary-analysis] tools: gdb radare2 ghidra strace ltrace binutils file patchelf valgrind binwalk nasm"
  '';
}
