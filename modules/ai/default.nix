# AI-EDITABLE DIRECTORY: opt-in auto-import root for AI-generated NixOS modules.
#
# Only files that live directly inside this directory (no subdirectories) are
# imported, and this file itself is always excluded. This directory is
# intentionally separate from modules/*.nix (packages.nix, overlays.nix,
# shell.nix, desktop.nix) — auto-importing the whole modules/ tree would have
# swept up modules/overlays.nix (an overlay *function*, not a NixOS module)
# and broken evaluation. Keeping the AI's write scope to this one opt-in
# subdirectory avoids that class of bug entirely.
#
# This is a path allow-list, not a capability sandbox: any file here can set
# arbitrary NixOS options. See AGENTS.md and .github/scripts/ai_pipeline.py
# for the actual defense (mechanical scope checks + mandatory human review).
{ ... }:
{
  imports =
    let
      entries = builtins.readDir ./.;
      isImportable = name: type:
        type == "regular" && name != "default.nix" && builtins.match ".*\\.nix" name != null;
      names = builtins.filter (name: isImportable name entries.${name}) (builtins.attrNames entries);
    in
    map (name: ./. + "/${name}") names;
}
