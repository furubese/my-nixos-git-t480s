# issue #64 の回帰テスト (issue #101 で拡充)。
#
# niri設定(home/ai/niri.kdl)とnoctalia設定(home/ai/noctalia.nix)が
# 現行の構成 (noctalia 5.x: C++単体バイナリ / niri 26.04) と整合するかを
# 静的に検証する:
# - spawn-at-startup "noctalia" が存在すること (旧Quickshell(qs)経由ではない)
# - niri 26.04 で無効なアクション名・キー名を使っていないこと
#   (quit / show-hotkey-overlay / Page_Down・Page_Up / Mod+WheelScrollDown)
# - noctalia 5.x に存在しない IPC サブコマンド (msg launcher) を使っていないこと
# - 空のアセット差し替え (NOCTALIA_ASSETS_DIR=...) を使っていないこと
# - noctalia設定がTOML (config.toml) として配備されていること (5.xはJSONを読まない)
{ lib, ... }:
let
  niriConfig = builtins.readFile ../../home/ai/niri.kdl;
  noctaliaModule = builtins.readFile ../../home/ai/noctalia.nix;
in
{
  assertions = [
    {
      assertion = lib.hasInfix ''spawn-at-startup "noctalia"'' niriConfig;
      message = ''niri設定(home/ai/niri.kdl)に spawn-at-startup "noctalia" がない: Noctaliaが起動しない (issue #64)'';
    }
    {
      assertion =
        !lib.hasInfix "quickshell" niriConfig
        && !lib.hasInfix ''spawn-at-startup "qs"'';
      message = "niri設定に旧Quickshell版Noctaliaの起動指定が残っている (issue #64)";
    }
    {
      # niri 26.04: ホットキーオーバーレイのアクション名は show-hotkey-overlay
      assertion = lib.hasInfix "show-hotkey-overlay" niriConfig;
      message = "niri設定に show-hotkey-overlay がない (issue #101)";
    }
    {
      assertion = !lib.hasInfix "show-hotkeys-overlay" niriConfig;
      message = "niri設定に niri 26.04 で無効なアクション名 show-hotkeys-overlay が残っている (issue #101)";
    }
    {
      # niri 26.04: niriの終了アクションは quit (exit は無効)
      assertion = lib.hasInfix ''Mod+Shift+E { quit; }'' niriConfig;
      message = "niri設定の Mod+Shift+E が quit になっていない (issue #101)";
    }
    {
      assertion = !lib.hasInfix "exit;" niriConfig;
      message = "niri設定に niri 26.04 で無効なアクション名 exit が残っている (issue #101)";
    }
    {
      # niri 26.04: キー名は Page_Down / Page_Up (PageDown / PageUp は無効)
      assertion = !lib.hasInfix "PageDown" niriConfig && !lib.hasInfix "PageUp" niriConfig;
      message = "niri設定に niri 26.04 で無効なキー名 PageDown / PageUp が残っている (issue #101)";
    }
    {
      # niri 26.04: ホイールの Mod+WheelScrollDown* のような * 付き指定は無効
      assertion =
        !lib.hasInfix "WheelScrollDown*" niriConfig
        && !lib.hasInfix "WheelScrollUp*" niriConfig;
      message = "niri設定に niri 26.04 で無効なキー名 WheelScrollDown* / WheelScrollUp* が残っている (issue #101)";
    }
    {
      # noctalia 5.x: ランチャーのIPCは panel-toggle launcher (msg launcher は無効)
      assertion = !lib.hasInfix "msg launcher" niriConfig;
      message = "niri設定に noctalia 5.x に存在しない IPC「noctalia msg launcher」が残っている (issue #101)";
    }
    {
      # 空ディレクトリを NOCTALIA_ASSETS_DIR に渡すと起動警告が出るだけ
      assertion = !lib.hasInfix "NOCTALIA_ASSETS_DIR=" niriConfig;
      message = "niri設定に NOCTALIA_ASSETS_DIR= でのアセット差し替えが残っている (issue #101)";
    }
    {
      # noctalia 5.x は ~/.config/noctalia/ の *.toml のみを読む
      assertion =
        lib.hasInfix ''noctalia/config.toml'' noctaliaModule
        && !lib.hasInfix ''noctalia/config.json'' noctaliaModule;
      message = "noctalia設定の配備先が ~/.config/noctalia/config.toml (TOML) になっていない (issue #101)";
    }
  ];
}
