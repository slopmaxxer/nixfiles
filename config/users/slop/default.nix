{ lib, pkgs, inputs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];
  users.users.slop = {
    isNormalUser = true;
    uid = 1000;
    # Own group with Arch's GID, so the copied home keeps its group owner.
    group = "slop";
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ];
    # No password: SSH keys only, passwordless sudo.
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA/+iN407+HsfHbbC3tfdA8Yf4TZ08qXQMb4tb/SDAs+ emily@card"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1mECV9Etr/nLIgg1E2mpFvAW1RexhhsRKrF7XcDEZI github:pilz0"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPpRvU9RzGVXM4NTEf3rc7mCLagj2MngELLWS/G7v2a7 root@iphone"
    ];
  };

  users.groups.slop.gid = 1000;

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "antigravity-cli"
    "claude-code"
  ];

  home-manager.backupFileExtension = "before-nixos";
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.slop = {
    home.stateVersion = "26.11";

    # was `nix profile install` on Arch
    home.packages = with pkgs; [
      claude-code
      codex
      antigravity-cli # agy
    ];
    # gh-login, slopmail (copied with /home)
    home.sessionPath = [ "$HOME/.local/bin" ];

    programs.bash = {
      enable = true;
      shellAliases = {
        ls = "ls --color=auto";
        grep = "grep --color=auto";
        claude = "claude --dangerously-skip-permissions";
        agy = "agy --dangerously-skip-permissions";
        codex = "codex --dangerously-bypass-approvals-and-sandbox";
      };
      # Aliases that carry credentials stay out of this public repo: put them in ~/.bashrc.local.
      initExtra = ''
        PS1='[\u@\h \W]\$ '
        if [ -r ~/.bashrc.local ]; then . ~/.bashrc.local; fi
      '';
    };

    # Commits and tags are signed with an SSH key; GitHub shows them as "Verified".
    programs.git = {
      enable = true;
      signing = {
        format = "ssh";
        key = "~/.ssh/id_ed25519_signing.pub";
        signByDefault = true;
      };
      settings = {
        user = {
          name = "slop";
          email = "slopmoder@tutamail.com";
        };
        gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
        tag.gpgSign = true;
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
        pull.rebase = true;
      };
    };
    # `gh auth git-credential` as the credential helper for github.com (HTTPS remotes).
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
    };
    home.file.".ssh/allowed_signers".text = ''
      slopmoder@tutamail.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOTofPAGRTdGiTl7oeIWupx4euhHVkR3TyPsECnq2fWJ
    '';
    # Hydra instances for the `hydra` MCP server (github.com/slopmaxxer/hydra-mcp). Only paths to
    # the password files here; hydra-mcp reads them at login.
    xdg.configFile."hydra-mcp/config.toml".text = ''
      default = "kyouma"

      # friend's Hydra that builds our fork (project slopinger-hydra), account slopinger
      [instances.kyouma]
      url = "https://hydra.kyouma.net"
      username_file = "~/.secrets/hydra-kyouma/username"
      password_file = "~/.secrets/hydra-kyouma/password"

      # our dev instance (config/services/hydra.nix), admin slop
      [instances.freifick]
      url = "https://hydra.freifick.net"
      username = "slop"
      password_file = "~/.secrets/hydra/admin-password"

      [instances.nixos]
      url = "https://hydra.nixos.org"
    '';

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."git.dn42.dev" = {
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_signing";
        IdentitiesOnly = "yes";
      };
      # GitHub (account slopinger); project remotes use HTTPS via gh, this is for SSH use
      settings."github.com" = {
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519_github";
        IdentitiesOnly = "yes";
      };
    };

    # tuned for Claude Code (and other modern TUIs)
    programs.tmux = {
      enable = true;
      terminal = "tmux-256color";
      escapeTime = 10;
      focusEvents = true;
      historyLimit = 50000;
      mouse = true;
      extraConfig = ''
        # Outer terminals get true colour, hyperlinks and extended keys
        set -as terminal-features ",xterm*:RGB:hyperlinks:extkeys:clipboard:focus"
        set -as terminal-features ",xterm-kitty:RGB:hyperlinks:extkeys:clipboard:focus"
        set -as terminal-features ",alacritty*:RGB:hyperlinks:extkeys:clipboard:focus"

        # Extended keys so Shift+Enter (newline in the prompt), Ctrl+Enter etc. reach apps
        set -s extended-keys on
        set -s extended-keys-format csi-u

        # Pass OSC sequences (desktop notifications, progress, title) to the outer terminal
        set -g allow-passthrough on

        # Copy to the local clipboard via OSC 52 (works over SSH)
        set -s set-clipboard on
      '';
    };
  };
}
