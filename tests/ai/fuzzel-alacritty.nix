# issue #63 の回帰テスト。
# fuzzel / alacritty がシステムプロファイルに導入され、niriのspawnが
# コマンドをPATHから解決できる状態になっていることをVM上で確認する。
#
# niriのキーバインド(Mod+D→fuzzel, Mod+T→alacritty)自体はniriのデフォルト設定に
# 含まれるため、GPUが無くGUIを起動できないVMテストでは
# 「spawn対象コマンドがPATHに存在すること」を代替として検証する。
#
# review対応: 対象モジュールは modules/ai/fuzzel.nix と modules/ai/alacritty.nix の
# 2つに分割されたため、両方をimportして検証する
# （1つのVMで両方確認できれば十分なため、テストファイルは統合のまま）。
{ ... }:
{
  name = "ai-fuzzel-alacritty";
  nodes.machine = {
    imports = [
      ../../modules/ai/fuzzel.nix
      ../../modules/ai/alacritty.nix
    ];
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target");
    machine.succeed("command -v fuzzel");
    machine.succeed("command -v alacritty");
    machine.succeed("alacritty --version");
  '';
}
