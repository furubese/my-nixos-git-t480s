# GitButler（issue #40）: 仮想ブランチ方式のGit GUIクライアント。
# niriデスクトップ（modules/ai/niri-desktop.nix）上で使うGUIアプリ。git CLI自体は
# modules/packages.nix で既に導入済みのため、ここではGUIクライアントのパッケージのみ追加する。
# modules/ai/*.nix はNixOSモジュールとして自動importされるため、hosts/側の設定変更は不要。
#
# 注意: GitButlerはgitの user.name / user.email の設定を要求する。
# 未設定の場合は ~/.gitconfig 等で別途設定すること（名前・メールアドレスはここでは扱わない）。
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [ gitbutler ];
}
