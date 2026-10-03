# 【重複解消（PRレビュー指摘）】
#
# 既存リポジトリには人間管理の home/noctalia.nix（設定実体: home/noctalia-settings.toml）が
# 既に存在し、noctalia のユーザー設定（~/.config/noctalia/settings.toml）の配備を担っている。
# 本PRで home/ai/ 側に追加していた xdg.configFile."noctalia/settings.toml" の定義は
# これと重複するため、このファイルの設定はすべて削除した。
#
# 今後の noctalia ユーザー設定の編集は、既存の home/noctalia.nix および
# home/noctalia-settings.toml（人間管理・AI編集スコープ外）で行うこと。
#
# 注: home/ai/ 配下の .nix は自動importされるため、何も定義しない空モジュールとして
# 残している（コメントのみの .nix はパースエラーになるため { } が必要）。
# このファイル自体は git rm して問題ない。
{ }
