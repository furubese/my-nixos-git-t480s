# issue #42: AI系CLIツールの導入
#
# nixpkgsにパッケージが実在するもののみを systemPackages に追加する。
# いずれも純粋なCLIツールなので、パッケージをPATHへ追加するだけで有効化される
# （lightdm/niriのような enable 系オプションは不要）。
#
#   - claude-code: Anthropic公式のClaude Code CLI。
#     unfreeライセンスのため nixpkgs.config.allowUnfree = true が必要
#     （hosts/t480s/configuration.nix で既に有効化済み）
#   - opencode: SST製のターミナル向けAIコーディングエージェント
#
# issue #42 でリクエストされたうち、以下は nixpkgs に該当パッケージが
# 存在しないため今回は見送り（配布元が判明すれば別途追加する）:
#   - OpenClaude:     該当するnixpkgsパッケージなし
#   - AntigravityCli: 該当するnixpkgsパッケージなし
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    claude-code
    opencode
  ];
}
