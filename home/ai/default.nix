# AI-EDITABLE DIRECTORY: opt-in auto-import root for AI-generated Home Manager
# modules. See modules/ai/default.nix for the rationale (opt-in subdirectory,
# not a wholesale home/** auto-import) and AGENTS.md for the security model.
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
