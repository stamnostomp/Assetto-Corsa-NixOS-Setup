# modules/shell.nix
# Defines the development shell for the Assetto Corsa NixOS setup

{ pkgs, packages }:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Core dependencies
    wget
    unzip
    gnutar

    # Wine and related tools
    wine
    winetricks

    # The setup tool itself
    packages.assettocorsa-tool
  ];

  shellHook = ''
    echo "Assetto Corsa Setup Tool Environment"
    echo "Run 'assettocorsa-tool' to start the interactive setup menu"
  '';
}
