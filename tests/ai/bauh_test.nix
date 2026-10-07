# issue #92 の回帰テスト (静的検証)。
#
# bauh は nixpkgs に存在せず PyPI sdist からのビルドになるため、
# 典型的な壊れ方を modules/ai/bauh.nix / modules/ai/flatpak.nix の内容で検証する:
# - bauh が environment.systemPackages に入っていること
# - python3.pkgs.buildPythonApplication + fetchPypi (0.10.7) でビルドしていること
# - 依存 (pyqt5 等) が propagatedBuildInputs に並んでいること
# - bauh が操作する flatpak CLI が services.flatpak.enable で有効化されていること
# - nixpkgs に存在しない pkgs.bauh を直接参照していないこと (評価エラーになる)
{ lib, ... }:
let
  bauhModule = builtins.readFile ../../modules/ai/bauh.nix;
  flatpakModule = builtins.readFile ../../modules/ai/flatpak.nix;
in
{
  assertions = [
    {
      assertion = lib.hasInfix "environment.systemPackages = [ bauh ]" bauhModule;
      message = "bauh設定(modules/ai/bauh.nix)がenvironment.systemPackagesにbauhを入れていない (issue #92)";
    }
    {
      assertion = lib.hasInfix "buildPythonApplication" bauhModule;
      message = "bauh設定がpython3のbuildPythonApplicationでビルドされていない (issue #92)";
    }
    {
      assertion = lib.hasInfix "fetchPypi" bauhModule && lib.hasInfix ''version = "0.10.7"'' bauhModule;
      message = "bauh設定がPyPIのsdist 0.10.7を参照していない (issue #92)";
    }
    {
      assertion =
        lib.hasInfix "pyqt5" bauhModule
        && lib.hasInfix "requests" bauhModule
        && lib.hasInfix "colorama" bauhModule
        && lib.hasInfix "pyyaml" bauhModule
        && lib.hasInfix "python-dateutil" bauhModule;
      message = "bauh設定にrequirements.txtの依存 (pyqt5/requests/colorama/pyyaml/python-dateutil) がない (issue #92)";
    }
    {
      assertion = lib.hasInfix "services.flatpak.enable = true" flatpakModule;
      message = "flatpak設定(modules/ai/flatpak.nix)のservices.flatpak.enableが無効化されている (issue #92: bauhはflatpak CLIを必要とする)";
    }
    {
      assertion = !lib.hasInfix "pkgs.bauh" bauhModule && !lib.hasInfix "pkgs.bauh" flatpakModule;
      message = "nixpkgsに存在しないpkgs.bauhを直接参照している (評価エラーになる: issue #92)";
    }
  ];
}
