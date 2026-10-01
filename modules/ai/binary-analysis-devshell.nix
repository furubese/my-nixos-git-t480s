# issue #35: バイナリ解析用環境（gdb / radare2 / ghidra / strace / ltrace 等）の整備。
#
# issue本文は flake.nix の devShells 出力による devshell 化を求めているが、
# flake.nix はAI編集スコープ外（人間編集ファイル）のため、NixOSモジュール側で
# `bin-analysis` コマンドを提供する。実行するとツール一式をPATHに載せた対話シェルに
# 入る（devshell相当。ツールはシステム全体のPATHには出さない）。
# 注: wrapperがツール一式を参照するため、ツール自体はシステムクロージャに含まれる。
#
# flake の devShells に接続する場合は tests/ai/binary-analysis-devshell.nix
# （mkShell定義）を flake.nix から import すること（要人間による flake.nix 編集）。
# ツール一覧を変更する場合は両ファイルを同期すること。
{ pkgs, lib, ... }:

let
  # バイナリ解析用ツール一式（tests/ai/binary-analysis-devshell.nix と同期）。
  # ghidra は nixpkgs で unfree 扱いのため allowUnfree が必要
  # （hosts/t480s/configuration.nix で有効化済み）。
  toolNames = [
    "gdb"
    "radare2"
    "ghidra"
    "strace"
    "ltrace"
    "binutils"
    "file"
    "patchelf"
    "valgrind"
    "binwalk"
    "nasm"
  ];

  tools = map (name: pkgs.${name}) toolNames;

  # 使い方:
  #   bin-analysis               ... ツール一式をPATHに載せた対話シェルに入る
  #   bin-analysis gdb ./binary  ... ツール付きPATHでコマンドを直接実行
  bin-analysis = pkgs.writeShellScriptBin "bin-analysis" ''
    export PATH="${lib.makeBinPath tools}:$PATH"
    if [ "$#" -gt 0 ]; then
      exec "$@"
    fi
    echo "[bin-analysis] tools: ${lib.concatStringsSep " " toolNames}"
    exec "''${SHELL:-${pkgs.bashInteractive}/bin/bash}"
  '';
in
{
  environment.systemPackages = [ bin-analysis ];
}
