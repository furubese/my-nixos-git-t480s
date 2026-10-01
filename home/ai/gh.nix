# GitHub CLI (gh) を使えるようにする（issue #52）。
# ghは認証情報（~/.config/gh/hosts.yml）や設定（~/.config/gh/config.yml）を
# ユーザー単位で保持するツールのため、システム側（modules/ai/）ではなく
# Home Manager側（home/ai/）で有効化する。
# 導入後の認証は `gh auth login` で対話的に行う（hosts.yml は宣言管理の対象外のため
# 通常の認証フローがそのまま使える）。
# gh自体の設定（エディタ等）を変えたい場合は programs.gh.settings で宣言的に管理する。
{ ... }:
{
  programs.gh.enable = true;
}
