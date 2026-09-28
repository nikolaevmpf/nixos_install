{
  description = "NixOS installation with Disko";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, disko, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      modules = [
        disko.nixosModules.disko
        ./disko.nix
        ./hardware-configuration.nix
        ./configuration.nix
      ];
    };
  };
}
