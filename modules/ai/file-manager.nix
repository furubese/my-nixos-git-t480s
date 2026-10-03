# issue #33: ファイルマネージャの整備
# issue #86: nautilus で "Not authorized to perform operation." が出る問題の修正
#
# nautilus / dolphin / nemo を比較検討し、nautilus (GNOME Files) を採用した。
# 理由:
#   - GTK4/libadwaita による Wayland ネイティブ実装で、niri デスクトップ
#     (modules/ai/niri-desktop.nix) と技術スタックが一致し、依存も最小
#   - dolphin は Plasma/KDE 向けの Qt アプリで KDE Frameworks を大きく
#     引き込むため、niri 環境ではスタックが重複して過剰
#   - nemo は Nautilus 3.x 系のフォークで Cinnamon/xapp 系の依存が増え、
#     Wayland 対応の開発リソースも GNOME 本流に比べて劣る
#
# なお nautilus はパッケージを入れるだけではゴミ箱・リムーバブルメディア・
# ネットワーク場所 (sftp:// 等) が動かないため、gvfs/udisks2 を併せて
# 有効化している。
#
# ---- issue #86 の調査結果と修正 ----
# 原因: nautilus が USBメモリ等をマウントするとき、gvfs は udisks2 の
# D-Bus API を呼ぶ。udisks2 の操作は polkit で認可されるが、polkit の
# 標準ルールは「logind で active なローカルセッション」のみを許可する。
# niri (greetd 経由) のセッションが logind 上で active と判定されない
# 環境では、認証ダイアログすら出ずに "Not authorized to perform
# operation." で即座に拒否される。
# 修正:
#   1. polkit を明示的に有効化 (security.polkit.enable)
#   2. wheel グループのユーザによる udisks2 操作を許可する polkit ルールを追加
#      (セッションの active 判定に依存しない)
#   3. ユーザ fse を storage / disk グループに追加し、ブロックデバイスの
#      操作権限を保証する
{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    nautilus
  ];

  # nautilus の各種設定 (表示モード・並び順等) を永続化する dconf の DBus サービス
  programs.dconf.enable = true;

  # ゴミ箱・リムーバブルメディア・ネットワーク場所のサポート (GVfs)
  services.gvfs.enable = true;

  # USBメモリ等のブロックデバイスの検出とマウント (udisks2)
  services.udisks2.enable = true;

  # nautilus 上でスペースキーを押したときのクイックプレビュー (Sushi)
  services.gnome.sushi.enable = true;

  # polkit: udisks2 の認可に必要。
  # niri-desktop.nix でも有効化しているが、このモジュール単体でも
  # 動作するようここでも明示しておく (重複設定はマージされる)。
  security.polkit.enable = true;

  # udisks2 の操作 (マウント・アンマウント等) を wheel グループの
  # ローカルユーザに許可する。標準ルールが要求する「active な
  # ローカルセッション」の判定に依存しないため、niri セッションで
  # active 判定が失敗していてもマウントできる。
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.udisks2.") === 0 &&
          subject.local && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # ユーザ fse を storage / disk グループに追加。
  # hosts/t480s/configuration.nix の users.users."fse".extraGroups は
  # ここで追記マージされる (wheel / networkmanager は元の定義のまま)。
  users.users."fse".extraGroups = [ "storage" "disk" ];

  # 「フォルダを開く」操作の既定アプリを nautilus に固定する
  xdg.mime.defaultApplications."inode/directory" = [ "org.gnome.Nautilus.desktop" ];
}
