# 日本語入力（fcitx5 + Mozc）のユーザー側設定（issue #26）。
# システム側の有効化（i18n.inputMethod）は modules/ai/japanese-input.nix を参照。
#
# このファイルの役割：
#   1. fcitx5 デーモンの自動起動（niri は XDG autostart を処理しないため）
#   2. Mozc を最初から使える状態にする fcitx5 プロファイルの配置
#   3. greetd からセッションが起動される構成でも IM 環境変数が
#      確実にセッションへ渡るようにする
{ pkgs, ... }:

let
  # modules/ai/japanese-input.nix の i18n.inputMethod.fcitx5.addons と同じ構成。
  # fcitx5-with-addons にしておくと、このservice単体で起動しても
  # Mozc アドオンを発見できる。
  # 注: fcitx5-with-addons は nixpkgs のトップレベル属性として存在する
  # （NixOS の i18n.inputMethod が内部で使うのと同じラッパー）。
  fcitx5Package = pkgs.fcitx5-with-addons.override {
    addons = [ pkgs.fcitx5-mozc ];
  };
in
{
  # niri 等の Wayland コンポジザは XDG autostart を処理しないため、
  # niri-session が有効化する graphical-session.target に紐付けて起動する
  systemd.user.services.fcitx5 = {
    Unit = {
      Description = "fcitx5 input method framework";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${fcitx5Package}/bin/fcitx5";
      # fcitx5 は XDG_DATA_DIRS 配下の share/fcitx5/addon からアドオン（Mozc）を
      # 探索するため、systemd user session の環境に依存せず見つかるよう明示指定する
      Environment = [
        "XDG_DATA_DIRS=${fcitx5Package}/share:/run/current-system/sw/share"
      ];
      Restart = "on-failure";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  # GTK/Qt/XIM アプリが fcitx5 を使うための環境変数。
  # NixOS 側（i18n.inputMethod）でも同じ値が設定されるが、greetd 経由でセッションが
  # 起動される構成でも取りこぼしがないよう Home Manager 側でも設定する
  # （シェルから起動したプロセスにはこちらが反映される）。
  home.sessionVariables = {
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  # systemd user session（user manager が起動するユニット）にも環境変数が渡るよう、
  # environment.d に同じ値を書き出す。greetd + niri-session 構成ではセッションの
  # 環境は niri-session が /etc/profile を読み込むことで設定されるが、
  # systemd user session 側には environment.d 経由で別途伝わるようにする。
  xdg.configFile."environment.d/90-fcitx5.conf".text = ''
    GTK_IM_MODULE=fcitx
    QT_IM_MODULE=fcitx
    XMODIFIERS=@im=fcitx
    SDL_IM_MODULE=fcitx
    GLFW_IM_MODULE=ibus
  '';

  # Mozc を最初から入力メソッド一覧に登録しておくプロファイル。
  # 半角/全角 または Ctrl+Space で keyboard-jp（英数直接入力）と
  # Mozc（かな漢字変換）を切り替えられる。
  # 注意: このファイルは read-only で管理されるため、fcitx5-configtool で入力メソッドの
  # 構成を変更しても保存されない。構成を変えたい場合はこのファイルを編集して反映すること。
  xdg.configFile."fcitx5/profile" = {
    source = ./fcitx5-profile.conf;
  };
}
