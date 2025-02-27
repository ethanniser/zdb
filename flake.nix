{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nvim.url = "github:ethanniser/nvim.nix";
    nvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, nvim, ... }: let
    pkgs = import nixpkgs {
      system = "x86_64-linux";
      overlays = [nvim.overlays.default];
    };
  in {
    devShells = {
      x86_64-linux = {
        default = pkgs.mkShell {
          packages = with pkgs; [
            zig
            zls
            just
            configured-nvim
          ];
        };
      };
    };
  };
}

