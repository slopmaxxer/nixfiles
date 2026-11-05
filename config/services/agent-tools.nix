# Development and agent tooling (Claude Code, Codex, Antigravity and their MCP servers).
# The MCP configs in ~/.claude.json, ~/.codex/config.toml and ~/.gemini/config/mcp_config.json are
# copied with /home; they call /usr/bin/{playwright-mcp,chromium} and /usr/local/bin/github-mcp,
# so those paths are kept as links (the Arch github-mcp launcher used ~/.nix-profile, which does
# not survive the move). uvx/npx servers resolve through PATH.
{ pkgs, ... }: let
  # GitHub MCP server as slopmaxxer; the token is read at runtime, never stored in Nix.
  github-mcp = pkgs.writeShellScriptBin "github-mcp" ''
    set -euo pipefail
    TOKEN_FILE="/home/slop/.secrets/github/slopmaxxer-token"
    if [[ ! -r "$TOKEN_FILE" ]]; then
      echo "Error: GitHub token file not found or not readable at $TOKEN_FILE" >&2
      exit 1
    fi
    GITHUB_PERSONAL_ACCESS_TOKEN="$(<"$TOKEN_FILE")"
    export GITHUB_PERSONAL_ACCESS_TOKEN
    exec ${pkgs.github-mcp-server}/bin/github-mcp-server stdio "$@"
  '';
in {
  environment.systemPackages = with pkgs; [
    # languages and builds (was base-devel, go, gleam, erlang, rebar3, nodejs/npm, uv on Arch)
    gcc gnumake pkg-config
    go gleam beamPackages.erlang beamPackages.rebar3 nodejs uv
    (python3.withPackages (p: [ p.pillow p.websockets p.pip ]))
    gh git-filter-repo sqlite rsync docker-compose
    # Language servers for Claude Code, Codex, Antigravity, and Pi
    rust-analyzer
    gopls
    pyright
    clang-tools # clangd
    typescript-language-server
    nil
    bash-language-server
    lua-language-server
    yaml-language-server
    marksman
    vscode-langservers-extracted
    # Code formatters for agents and pi-formatter
    nixfmt
    rustfmt
    shfmt
    ruff
    # MCP servers on PATH (playwright was a global npm package on Arch)
    playwright-mcp therapie-mcp arbeitsagentur-mcp github-mcp
    # Browser automation: headless Chromium, virtual X11 (Xvfb :99 + openbox + scrot + xdotool)
    chromium xorg-server openbox scrot xdotool
  ];

  # Headless Chromium hangs on page loads without fonts/fontconfig.
  fonts.packages = with pkgs; [ dejavu_fonts liberation_ttf noto-fonts noto-fonts-color-emoji ];

  # Copied Python venvs (e.g. the nodriver venv), uv-managed interpreters and prebuilt
  # npm binaries expect a regular dynamic loader.
  programs.nix-ld.enable = true;

  systemd.tmpfiles.rules = [
    "L+ /usr/bin/chromium - - - - /run/current-system/sw/bin/chromium"
    "L+ /usr/bin/playwright-mcp - - - - /run/current-system/sw/bin/playwright-mcp"
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/github-mcp - - - - /run/current-system/sw/bin/github-mcp"
    "L+ /usr/local/bin/slopmail - - - - /home/slop/.local/bin/slopmail"
    "L+ /usr/local/bin/gh-login - - - - /home/slop/.local/bin/gh-login"
  ];
}
