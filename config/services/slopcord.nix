# Slopcord Discord bot and voice controller for local AI agents.
# Source: https://github.com/slopmaxxer/slopcord (flake input `slopcord`).
{ inputs, ... }: {
  imports = [ inputs.slopcord.nixosModules.default ];

  services.slopcord = {
    enable = true;
    user = "slop";
    configFile = "/home/slop/.secrets/discord/config.json";
  };
}
