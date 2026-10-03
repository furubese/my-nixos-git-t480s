# issue #86: nautilus で "Not authorized to perform operation" エラー
#
# 【調査結果】
# 1. services.udisks2.enable / services.gvfs.enable は modules/ai/file-manager.nix
#    で既に有効 → udisks2 自体は問題なし。
# 2. ユーザー fse のグループ (hosts/t480s/configuration.nix):
#    wheel / networkmanager に所属。udisks2 のマウントは disk グループではなく
#    polkit による認可で行われるため、グループ設定は原因ではない。
# 3. 真の原因: udisks2 のマウントは polkit (org.freedesktop.udisks2.*) で認可されるが、
#    greetd + niri の非標準セッションでは logind の "active" セッション判定が
#    うまく働かず、標準ルール (active session は mount 許可) から除外されて
#    "Not authorized to perform operation" となる。
#
# 【修正】
# - polkit を有効化し、wheel グループのユーザーによる udisks2 の
#   マウント系操作を明示的に許可するルールを追加する。
#   (fse は wheel に所属しているため、これで nautilus からのマウントが通る)
# - 認証エージェント (noctalia polkit_agent) は home/ai/noctalia.json で有効化済み。
#   念のため polkit-gnome の認証エージェントもインストールしておく
#   (noctalia 側のエージェントが起動しない場合のフォールバック)。
{ pkgs, ... }:

{
  security.polkit.enable = true;

  security.polkit.extraConfig = ''
    // issue #86: udisks2 のマウント操作を wheel ユーザーに許可する。
    // niri + greetd 環境では logind の active セッション判定が機能せず、
    // 標準の udisks2 ルールで拒否されるため、明示的に許可する。
    polkit.addRule(function(action, subject) {
      var allow = [
        "org.freedesktop.udisks2.filesystem-mount",
        "org.freedesktop.udisks2.filesystem-mount-system",
        "org.freedesktop.udisks2.filesystem-mount-other-seat",
        "org.freedesktop.udisks2.encrypted-unlock",
        "org.freedesktop.udisks2.eject-media",
        "org.freedesktop.udisks2.power-off-drive"
      ];
      if (subject.isInGroup("wheel")
          && allow.indexOf(action.id) >= 0) {
        return polkit.Result.YES;
      }
    });
  '';

  # polkit 認証エージェントのフォールバック (noctalia のエージェントが
  # 利用できない場合に手動起動できるようにバイナリを配置)
  environment.systemPackages = with pkgs; [
    polkit_gnome
  ];
}
