# 【廃止】issue #63 で導入していた fuzzel + alacritty の結合モジュール。
#
# reviewコメント「fuzzelとalacrittyは別のモジュールとすべきである」を受け、
# 実装は次の2つの独立モジュールへ分割した:
#   - modules/ai/fuzzel.nix    (fuzzel + 表示用Notoフォント)
#   - modules/ai/alacritty.nix (alacritty + 表示用Notoフォント)
#
# このファイルはAI編集スコープの制約（既存ファイルの削除は不可）により残置している
# 互換forwardingで、旧パスを import している箇所が残っていても壊れないよう
# 分割後の2モジュールを再exportするだけの内容。このファイル自体は設定を宣言しない。
# 新規に参照する場合は分割後のモジュールを直接 import すること
# （tests/ai/fuzzel-alacritty.nix は本PRで直接参照へ更新済み）。
#
# modules/ai/ は hosts/t480s/configuration.nix から自動importされるため、
# このファイル経由で分割モジュールが二重にimportされることになるが、
# NixOSのモジュールシステムは同一パスのモジュールを1回しか適用しないため無害。
# 他に参照がなければこのファイルは削除してよい。
{ ... }:
{
  imports = [
    ./fuzzel.nix
    ./alacritty.nix
  ];
}
