# Assetto Corsa NixOS Setup Tool


A Nix flake to easily set up Assetto Corsa with Content Manager and Custom Shaders Patch on NixOS and other Linux distributions with Nix.

## Features

- Interactive menu-based setup
- Content Manager installation and configuration
- Custom Shaders Patch (CSP) installation
- Enhanced DXVK setup with multiple installation methods
- Automatic path fixing for Content Manager
- Multiple Steam installation path detection
- Supports both App IDs used by Assetto Corsa (244210 and 244930)
- Wine 64-bit compatibility fixes for black screen issues
- Content Manager UI black box fixes
- Steam launch options configuration
- Advanced diagnostics and troubleshooting tools
- Optimized for Proton GE compatibility

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
4. **Install DXVK**: Improves performance with AMD GPUs using standard installation
5. **Check for problematic shortcuts**: Removes shortcuts that can cause crashes
6. **Reset Assetto Corsa to original**: Removes Content Manager and restores the original game executable
7. **Show setup information**: Displays information about your current setup
8. **Set or change Assetto Corsa path**: Change the path to your Assetto Corsa installation
9. **Force DXVK installation**: Uses more aggressive methods to ensure DXVK is properly installed
10. **Run advanced diagnostics and fixes**: Performs comprehensive system checks and offers repair options
11. **Fix Wine 64-bit compatibility**: Resolves black screen issues with 64-bit Wine prefixes
12. **Setup Steam launch options**: Configures optimal Steam launch options for DXVK and Proton
13. **Fix Content Manager UI black boxes**: Resolves UI rendering issues in menus and hamburger button

## DXVK Installation Improvements

This tool provides enhanced DXVK installation with multiple methods:
- Standard installation using winetricks
- Manual DLL overrides directly in the Wine registry
- Optional specific DXVK version (1.10.3 recommended for Assetto Corsa)
- Force mode to fix potential issues with the standard installation
- Registry validation and multiple fallback methods

## Wine 64-bit Compatibility

The tool can detect and fix issues with 64-bit Wine prefixes:
- Automatically detects Wine prefix architecture
- Creates specialized launcher scripts for Proton GE
- Sets up proper environment variables for optimal compatibility
- Creates desktop entries for easy launching
- Configures Wine with correct library paths

## Content Manager UI Fixes

Resolves common UI rendering issues in Content Manager:
- Fixes black box issues in menus
- Resolves rendering problems with the hamburger menu button
- Configures optimal Windows transparency settings
- Disables hardware acceleration for UI elements when appropriate
- Sets correct DXGI wrapper and Direct3D feature level

## Advanced Diagnostics

The diagnostics tool provides comprehensive system checks:
- Wine and prefix architecture compatibility verification
- Vulkan support detection and configuration
- DXVK DLL status verification
- Emergency direct DXVK installation options
- Graphics driver recommendations
- Content Manager settings optimization
- NixOS-specific configuration suggestions

## Troubleshooting

### Content Manager can't find Assetto Corsa

If Content Manager still can't find your Assetto Corsa installation after using the "Fix Content Manager Paths" option, you may need to manually point it to:

```
/home/yourusername/.local/share/Steam/steamapps/common/assettocorsa
```

### CSP not working properly

Make sure you have installed the Custom Shaders Patch and that the DLL overrides are properly set. You can reinstall CSP using menu option 3.

### Game crashes on startup

Check for the Start Menu shortcut issue using menu option 5. This is a common cause of crashes with Content Manager.

### Black screen on startup

If you're experiencing a black screen when launching Content Manager:
1. Use option 11 to fix Wine 64-bit compatibility issues
2. Make sure you're using the correct Wine architecture for your prefix
3. Try using the Proton GE launcher script created by the tool

### UI shows black boxes or rendering issues

If Content Manager's UI has black boxes or hamburger menu problems:
1. Use option 13 to apply UI rendering fixes
2. In Content Manager, go to Settings > System and check "Disable windows transparency"
3. Also disable hardware acceleration for UI if problems persist

### Graphics issues or poor performance

- Try reinstalling DXVK using menu option 4, or use option 9 for a forced installation
- Use option 12 to set optimal Steam launch options with DXVK_HUD=full
- In Content Manager, go to Settings > System and ensure "Enable DXVK" is checked
- Use option 10 to run advanced diagnostics and get system-specific recommendations

## Development

To work on this tool:

```bash
git clone https://github.com/stamnostomp/assettocorsa-nixos-setup.git
cd assettocorsa-nixos-setup
nix develop
assettocorsa-tool
```

## Project Structure

The project is organized as follows:
- `flake.nix`: Main entry point for the Nix flake
- `modules/`: Nix modules for packages and development shell
- `scripts/`: Bash scripts for each component installation
  - `main.nix`: Main menu and orchestration
  - `utils.nix`: Shared utility functions
  - `content-manager.nix`: Content Manager installation
  - `csp.nix`: Custom Shaders Patch installation
  - `dxvk.nix`: Enhanced DXVK installation
  - `diagnostics.nix`: Advanced system diagnostics
  - `wine64-fix.nix`: Wine 64-bit compatibility fixes
  - `steam-launcher.nix`: Steam launch options configuration
  - `cm-ui-fix.nix`: Content Manager UI rendering fixes

## License

MIT
