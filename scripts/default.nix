# scripts/default.nix
# Defines the scripts for the Assetto Corsa NixOS setup

{ pkgs, cspVersion }:

let
  # Core utility functions
  utils = import ./utils.nix { inherit pkgs; };

  # Individual components
  contentManager = import ./content-manager.nix { inherit pkgs utils; };
  csp = import ./csp.nix { inherit pkgs utils cspVersion; };
  dxvk = import ./dxvk.nix { inherit pkgs utils; };
  diagnostics = import ./diagnostics.nix { inherit pkgs utils; };
  wine64Fix = import ./wine64-fix.nix { inherit pkgs utils; };
  steamLauncher = import ./steam-launcher.nix { inherit pkgs utils; };
  cmUiFix = import ./cm-ui-fix.nix { inherit pkgs utils; };

  # Main script that incorporates all components
  main = import ./main.nix {
    inherit
      pkgs
      utils
      contentManager
      csp
      dxvk
      diagnostics
      wine64Fix
      steamLauncher
      cmUiFix
      ;
  };

in
{
  inherit
    main
    utils
    contentManager
    csp
    dxvk
    diagnostics
    wine64Fix
    steamLauncher
    cmUiFix
    ;
}
