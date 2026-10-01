# Noctaliaシェル（issue #64）
#
# 【経緯】
# 旧NoctaliaはQuickshell(QML)ベースで、quickshellのランチャ(qs)経由で起動する作りだった。
# 現行のNoctaliaはC++実装の単体バイナリに書き直されており、quickshellは不要。
# niri側の設定(home/ai/niri.kdl)では `spawn-at-startup "noctalia"` で直接起動する。
#
# 【パッケージ方針】
# nixpkgsに `noctalia` があればそれを使う。無ければ `noctalia-shell` という属性名で
# 入っていないか確認し、それも無ければインストールせず評価時に警告を出す
# （flake.nixへの上流flake入力の追加は人間管理のため、このモジュールからは
# nixpkgs由来のみ扱う。パッケージが見つからない場合は入力追加を依頼すること）。
#
# 【システムプロファイルに入れる理由】
# greetdから起動されたniriセッションのPATHにはユーザープロファイル
# (~/.nix-profile/bin)が載らない。niriのspawn-at-startupから参照できるよう、
# システム側(/run/current-system/sw/bin)に置く。
#
# 補足: `noctalia-shell` 属性にフォールバックした場合、バイナリ名が `noctalia`
# 以外であれば home/ai/niri.kdl のspawn-at-startupをそちらに合わせること。
{ pkgs, lib, ... }:
let
  noctalia =
    if pkgs ? noctalia then pkgs.noctalia
    else pkgs.noctalia-shell or null;
in
{
  environment.systemPackages =
    if noctalia == null then
      lib.warn
        "noctalia: nixpkgsにnoctalia/noctalia-shellパッケージが見つからないためインストールを見送ります（issue #64: flake.nixへの上流入力追加が必要）"
        [ ]
    else [ noctalia ];
}
