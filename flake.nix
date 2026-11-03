{
  description = "slop's infra: freifick.net as NixOS configuration";

  outputs = { self, nixpkgs, colmena, flake-utils, ... }@inputs: let
    sf = import ./lib/shinyflakes inputs;
    inherit (nixpkgs) lib;
  in {
    colmenaHive = colmena.lib.makeHive (sf.mapColmenaMerge self.nixosConfigurations {
      meta = {
        allowApplyAll = false;
        nixpkgs = nixpkgs.legacyPackages.x86_64-linux;
        specialArgs = { inherit inputs; };
      };
    });

    nixosConfigurations = sf.mapNixosCfg {
      hosts = sf.mapHostsMerge ./config/hosts {
        # Valve Steam Link (armv7l, 512 MiB): cross-compiled here, never built on the box.
        steamlink = {
          system = "armv7l-linux";
          buildSystem = "x86_64-linux";
        };
      };
    };

    # hydra.kyouma.net: armv7l has no binary cache, so the cross-built Steam Link system
    # and its USB image are built there and served from cache.kyouma.net.
    hydraJobs = let
      steamlink = self.nixosConfigurations.steamlink.config.system.build;
    in {
      steamlink = {
        toplevel = steamlink.toplevel;
        image = steamlink.sdImage;
      };
    };

    overlays = {
      freifick = import ./pkgs/overlay.nix inputs;
      default = self.overlays.freifick;
    };

    nixosModules = lib.genAttrs
      (builtins.attrNames (lib.filterAttrs (_: v: v == "directory") (builtins.readDir ./modules)))
      (mod: ./modules/${mod}) // lib.genAttrs
      [ "trough" "mayfly" "dn42" "driftline" "server-backups" "boybrowse" ]
      (name: inputs.${name}.nixosModules.default) // {
        slopd = inputs.slop-landing.nixosModules.default;
        hydra = inputs.hydra.nixosModules.hydra;
      };

    packages = sf.eachSystem (system: platform: let
      pkgs = sf.importPkgs system;
    in lib.filterAttrs (_: pkg: lib.meta.availableOn platform pkg) (sf.mapPackages pkgs system { }));

    checks = sf.eachSystem (system: _:
      lib.mapAttrs (_: host: host.config.system.build.toplevel)
        (lib.filterAttrs (_: host: host.pkgs.stdenv.hostPlatform.system == system) self.nixosConfigurations));
  } // flake-utils.lib.eachSystem [ "x86_64-linux" ] (system: let
    pkgs = sf.importPkgs system;
  in {
    devShells.default = pkgs.mkShell {
      packages = [ pkgs.colmena pkgs.nixos-anywhere ];
    };
    formatter = pkgs.nixfmt-rfc-style;
  });

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    colmena = {
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    trough = {
      url = "git+https://github.com/slopmaxxer/trough.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mayfly = {
      url = "git+https://github.com/slopmaxxer/mayfly.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dn42 = {
      url = "git+https://github.com/slopmaxxer/dn42.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    driftline = {
      url = "git+https://github.com/slopmaxxer/driftline.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    server-backups = {
      url = "git+https://github.com/slopmaxxer/server-backups.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    therapie-mcp = {
      url = "git+https://github.com/slopmaxxer/therapie-mcp.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    arbeitsagentur-mcp = {
      url = "git+https://github.com/slopmaxxer/arbeitsagentur-mcp.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    boybrowse = {
      url = "git+https://github.com/slopmaxxer/boybrowse.git";
    };
    # Soft fork of Lix's Hydra. No `follows`: its own lock keeps store paths equal to the
    # hydra.kyouma.net builds, which cache.kyouma.net serves.
    hydra.url = "git+https://github.com/slopmaxxer/hydra.git";
    # freifick.net static site + slopd (guestbook/counter backend)
    slop-landing = {
      url = "git+https://github.com/slopmaxxer/slop-landing.git";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
