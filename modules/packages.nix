# modules/packages.nix
# Defines the packages for the Assetto Corsa NixOS setup

{ pkgs }:

let
  # Define versions
  cspVersion = "0.2.7";

  # Import scripts
  scripts = import ../scripts { inherit pkgs cspVersion; };

  # Main script - Assetto Corsa setup tool
  assettocorsa-tool = pkgs.writeShellScriptBin "assettocorsa-tool" ''
    #!/usr/bin/env bash
    ${scripts.main}
  '';

in
{
  inherit assettocorsa-tool;
}
