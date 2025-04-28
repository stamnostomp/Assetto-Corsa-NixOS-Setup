# modules/default.nix
# Defines the packages, apps, and devShells for the Assetto Corsa NixOS setup

{ pkgs }:

let
  packages = import ./packages.nix { inherit pkgs; };
  shell = import ./shell.nix { inherit pkgs packages; };
in
{
  packages = {
    default = packages.assettocorsa-tool;
    inherit (packages) assettocorsa-tool;
  };

  apps = {
    default = {
      type = "app";
      program = "${packages.assettocorsa-tool}/bin/assettocorsa-tool";
    };
  };

  devShells = {
    default = shell;
  };
}
