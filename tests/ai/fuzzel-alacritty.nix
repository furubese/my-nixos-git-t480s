# issue #63 の回帰テスト。
# fuzzel / alacritty がシステムプロファイルに導入され、niriのspawnが
# コマンドをPATHから解決できる状態になっていることをVM上で確認する。
#
# niriのキーバインド(Mod+D→fuzzel, Mod+T→alacritty)自体はniriのデフォルト設定に
# 含まれるため、GPUが無くGUIを起動できないVMテストでは
# 「spawn対象コマンドがPATHに存在すること」を代替として検証する。
{ ... }:
{
  name = "ai-fuzzel-alacritty";
  nodes.machine = {
    # 該当モジュール単体を取り込んで検証する
    imports = [ ../../modules/ai/fuzzel-alacritty.nix ];
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target");
    machine.succeed("command -v fuzzel");
    machine.succeed("command -v alacritty");
    machine.succeed("alacritty --version");
  '';
}
