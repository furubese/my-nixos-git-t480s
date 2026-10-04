# issue #92: flatpak管理のためのGUIツール bauh を追加する。
#
# bauh は nixpkgs (nixos-26.05 / unstable) にパッケージが存在しないため、
# PyPI の sdist から python3.pkgs.buildPythonApplication でビルドして導入する。
#   - PyPI:   https://pypi.org/project/bauh/0.10.7/
#   - GitHub: https://github.com/vinifmor/bauh (tag 0.10.7)
#
# 必要な依存は requirements.txt 通り (pyqt5, requests, colorama, pyyaml,
# python-dateutil)。bauh が操作する flatpak CLI 自体は
# modules/ai/flatpak.nix の services.flatpak.enable でシステムに入る。
{ pkgs, ... }:

let
  python3 = pkgs.python3;
  python3Packages = python3.pkgs;

  bauh = python3Packages.buildPythonApplication rec {
    pname = "bauh";
    version = "0.10.7";

    src = python3Packages.fetchPypi {
      inherit pname version;
      hash = "sha256-N6zvEbx0Y2GGB9f5emmhNcWN6z0oPK0qoazKq0gIRC0=";
    };

    # requirements.txt の中身:
    #   pyqt5>=5.12, requests>=2.18, colorama>=0.3.8, pyyaml>=3.13,
    #   python-dateutil>=2.7
    propagatedBuildInputs = with python3Packages; [
      pyqt5
      requests
      colorama
      pyyaml
      python-dateutil
    ];

    # PyQt5アプリの起動に必要なQtプラグイン解決のため
    nativeBuildInputs = [ pkgs.qt5.wrapQtAppsHook ];

    # sdist は setup.py 形式 (pyproject.toml なし)
    pyproject = false;

    # 上流のテストスイートは現行環境では動かないため実行しない
    doCheck = false;

    postInstall = ''
      install -Dm644 ${python3.sitePackages}/bauh/desktop/bauh.desktop \
        $out/share/applications/bauh.desktop
      substituteInPlace $out/share/applications/bauh.desktop \
        --replace "/usr/bin/bauh" "$out/bin/bauh"
      install -Dm644 ${python3.sitePackages}/bauh/view/resources/img/logo.svg \
        $out/share/icons/hicolor/scalable/apps/bauh.svg
    '';

    meta = {
      description = "GUI to manage Linux applications (AppImage, Arch, Flatpak, Snap and Web)";
      homepage = "https://github.com/vinifmor/bauh";
      license = pkgs.lib.licenses.zlib;
      mainProgram = "bauh";
      platforms = pkgs.lib.platforms.linux;
    };
  };
in
{
  environment.systemPackages = [ bauh ];
}
