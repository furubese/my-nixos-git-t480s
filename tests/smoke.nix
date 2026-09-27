{ pkgs, ... }:
pkgs.testers.runNixOSTest {
  # nixos-26.05 に testers.runNixOSTest が無い場合は pkgs.nixosTest にフォールバックすること
  name = "smoke";
  nodes.machine = { ... }: {
    imports = [ ../modules/packages.nix ];
  };
  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("which git")
  '';
}
