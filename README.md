# Assetto Corsa NixOS Setup Tool

A Nix flake to easily set up Assetto Corsa with Content Manager and Custom Shaders Patch on NixOS and other Linux distributions with Nix.

## Features

- Interactive menu-based setup
- Content Manager installation and configuration
- Custom Shaders Patch (CSP) installation
- DXVK support for better performance on AMD GPUs
- Automatic path fixing for Content Manager
- Multiple Steam installation path detection
- Supports both App IDs used by Assetto Corsa (244210 and 244930)

## Quick Start

You can run this tool directly without cloning the repository:

```bash
nix run github:stamnostomp/assettocorsa-nixos-setup
```

Or clone the repository and run:

```bash
git clone https://github.com/stamnostomp/assettocorsa-nixos-setup.git
cd assettocorsa-nixos-setup
nix run
```

## Prerequisites

- Nix with flakes enabled
- Steam installed
- Assetto Corsa purchased and installed on Steam
- Proton or Proton GE set up for Assetto Corsa

## Setup Instructions

1. Make sure Assetto Corsa is installed through Steam
2. Launch Assetto Corsa at least once with Proton to generate the Wine prefix
3. Run the setup tool
4. Follow the interactive menu to install and configure components

## Menu Options

1. **Install/Update Content Manager**: Installs or updates the Content Manager for Assetto Corsa
2. **Fix Content Manager Paths**: Fixes path configuration for Content Manager to find your Assetto Corsa installation
3. **Install Custom Shaders Patch (CSP)**: Installs the Custom Shaders Patch for improved graphics
4. **Install DXVK**: Improves performance with AMD GPUs
5. **Check for problematic shortcuts**: Removes shortcuts that can cause crashes
6. **Reset Assetto Corsa to original**: Removes Content Manager and restores the original game executable
7. **Show setup information**: Displays information about your current setup

## Troubleshooting

### Content Manager can't find Assetto Corsa

If Content Manager still can't find your Assetto Corsa installation after using the "Fix Content Manager Paths" option, you may need to manually point it to:

```
/home/stamnostomp/.local/share/Steam/steamapps/common/assettocorsa
```

### CSP not working properly

Make sure you have installed the Custom Shaders Patch and that the DLL overrides are properly set. You can reinstall CSP using menu option 3.

### Game crashes on startup

Check for the Start Menu shortcut issue using menu option 5. This is a common cause of crashes with Content Manager.

## Development

To work on this tool:

```bash
git clone https://github.com/stamnostomp/assettocorsa-nixos-setup.git
cd assettocorsa-nixos-setup
nix develop
assettocorsa-tool
```

## License

MIT

