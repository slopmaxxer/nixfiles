{ self, nixpkgs, ... }@inputs: let
  inherit (nixpkgs) lib;
  inherit (builtins) mapAttrs;

  mergeWith = x: y: lib.recursiveUpdate y x;

  genColmenaCfg = name: host: {
    deployment = {
      allowLocalDeployment = true;
      buildOnTarget = host.config.freifick.deployment.buildOnTarget;
      targetHost = lib.findFirst (el: el != null) host.config.networking.fqdnOrHostName
        [ host.config.freifick.deployment.targetHost ];
      targetPort = 22;
      targetUser = "slop";
      tags = host.config.freifick.deployment.tags;
    };
    imports = host._module.args.modules;
    nixpkgs.system = host.config.nixpkgs.system;
  };

  genNixosCfg = {
    hostname,
    system ? "x86_64-linux",
    # Set to cross-compile the host (e.g. an armv7l board built on x86_64).
    buildSystem ? null
  }:
  lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      ../../config/hosts/${hostname}/configuration.nix
      ({ ... }: {
        nixpkgs.overlays = [ self.overlays.freifick ];
        nixpkgs.hostPlatform.system = system;
      })
      ({ ... }: lib.optionalAttrs (buildSystem != null) {
        nixpkgs.buildPlatform.system = buildSystem;
      })
    ];
  };
in {
  inherit genNixosCfg;

  mapHostsMerge = hdir: extraCfg:
    mergeWith extraCfg (lib.genAttrs
      (builtins.attrNames (lib.filterAttrs (n: t: t == "directory" && n != "_minimal") (builtins.readDir hdir)))
      (host: { hostname = host; }));

  mapColmenaMerge = nixosCfg: extraCfg:
    mergeWith extraCfg (mapAttrs genColmenaCfg nixosCfg);

  mapNixosCfg = {
    hosts,
    extraHosts ? {},
  }:
    mergeWith extraHosts (mapAttrs (_: v: genNixosCfg v) hosts);

  mapPackages = overlayPkgs: system:
    lib.recursiveUpdate (
      self.overlays.freifick overlayPkgs nixpkgs.legacyPackages.${system}
    );

  eachSystem = func: lib.mapAttrs func (import ./platforms.nix inputs);

  importPkgs = system: import nixpkgs {
    inherit system;
    overlays = [ self.overlays.freifick ];
  };
}
