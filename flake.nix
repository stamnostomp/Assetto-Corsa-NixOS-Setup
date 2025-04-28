# flake.nix
# Distributable Assetto Corsa Setup Tool for NixOS
#
# Usage:
# - Run directly: nix run github:your-username/assettocorsa-nix
# - Development: nix develop
#
# Features:
# - Full setup of Assetto Corsa with Content Manager
# - Automatic path configuration for Content Manager
# - Custom Shaders Patch installation
# - Compatible with various Steam installation paths

{
  description = "Assetto Corsa with Content Manager setup for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        modules = import ./modules { inherit pkgs; };
      in
      {
        packages = modules.packages;
        apps = modules.apps;
        devShells = modules.devShells;
      }
    );
}
