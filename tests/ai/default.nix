# AI-EDITABLE DIRECTORY (reserved): tests/ai/** is in the AI edit allow-list
# so a future AI-generated PR may add test modules alongside the config
# changes it makes. This directory is not yet wired into flake.nix's
# `checks` (flake.nix is intentionally outside the AI edit scope — see
# AGENTS.md), so files placed here have no effect on CI until a human wires
# them in, the same way tests/desktop-full.nix is currently an unregistered
# placeholder.
{ ... }: { }
