{ lib, ... }:
with lib;
{
  options.freifick.deployment = {
    tags = mkOption {
      type = with types; listOf str;
      default = [ ];
      description = "colmena deployment tags";
    };
    buildOnTarget = mkOption {
      type = types.bool;
      default = true;
      description = "colmena: build on the target instead of copying a locally built closure";
    };
    targetHost = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "colmena target host override";
    };
  };
}
