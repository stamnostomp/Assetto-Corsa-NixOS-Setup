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

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Define versions
        cspVersion = "0.2.7";

        # Main script - Assetto Corsa setup tool
        assettocorsa-tool = pkgs.writeShellScriptBin "assettocorsa-tool" ''
          #!/usr/bin/env bash

          # Color setup
          RED='\033[0;31m'
          GREEN='\033[0;32m'
          YELLOW='\033[1;33m'
          BLUE='\033[0;34m'
          BOLD='\033[1m'
          NC='\033[0m'

          # Banner
          echo -e "''${BLUE}''${BOLD}"
          echo "╔═══════════════════════════════════════════════════╗"
          echo "║       Assetto Corsa Setup Tool for NixOS          ║"
          echo "╚═══════════════════════════════════════════════════╝"
          echo -e "''${NC}"

          # Function to print section headers
          section() {
            echo -e "\n''${BLUE}''${BOLD}$1''${NC}\n"
          }

          # Function to print success messages
          success() {
            echo -e "''${GREEN}✓ $1''${NC}"
          }

          # Function to print warnings
          warning() {
            echo -e "''${YELLOW}⚠ $1''${NC}"
          }

          # Function to print errors
          error() {
            echo -e "''${RED}✗ $1''${NC}"
          }

          # Function to ask yes/no questions
          ask() {
            while true; do
              read -p "$1 [y/n]: " yn
              case $yn in
                [Yy]*) return 0 ;;
                [Nn]*) return 1 ;;
              esac
            done
          }

          # Function to create directories if they don't exist
          ensure_dir() {
            if [[ ! -d "$1" ]]; then
              mkdir -p "$1"
              echo "Created directory: $1"
            fi
          }

          # Print system information
          section "System Information"
          echo "Date: $(date)"
          echo "User: $USER"
          echo "Hostname: $(hostname)"
          echo "NixOS: $(nixos-version 2>/dev/null || echo "Not NixOS or command not found")"

          # Find Steam installation
          section "Finding Steam Installation"

          # Common Steam directories to check
          STEAM_DIRS=(
            "$HOME/.local/share/Steam"
            "$HOME/.steam/steam"
            "$HOME/.var/app/com.valvesoftware.Steam/data/Steam"
          )

          STEAM_PATH=""
          for dir in "''${STEAM_DIRS[@]}"; do
            if [[ -d "$dir" ]]; then
              STEAM_PATH="$dir"
              success "Found Steam at $STEAM_PATH"
              break
            fi
          done

          if [[ -z "$STEAM_PATH" ]]; then
            warning "Could not automatically find Steam directory."
            echo "Enter path to your Steam directory (e.g. $HOME/.local/share/Steam):"
            read -i "$HOME/" -e STEAM_PATH

            # Expand ~ to $HOME
            STEAM_PATH="$(echo "''${STEAM_PATH%"/"}" | sed "s|\~\/|$HOME\/|g")"

            if [[ ! -d "$STEAM_PATH" ]]; then
              error "Invalid Steam directory: $STEAM_PATH"
              exit 1
            fi
          fi

          # Find Assetto Corsa installation
          section "Finding Assetto Corsa Installation"

          AC_PATH="$STEAM_PATH/steamapps/common/assettocorsa"

          if [[ ! -d "$AC_PATH" ]]; then
            warning "Could not find Assetto Corsa in the default path."
            echo "Enter path to assettocorsa directory:"
            read -i "$HOME/" -e AC_PATH

            # Expand ~ to $HOME
            AC_PATH="$(echo "''${AC_PATH%"/"}" | sed "s|\~\/|$HOME\/|g")"

            if [[ ! -d "$AC_PATH" ]] || [[ $(basename "$AC_PATH") != "assettocorsa" ]]; then
              error "Invalid Assetto Corsa directory: $AC_PATH"
              exit 1
            fi
          fi

          success "Using Assetto Corsa directory: $AC_PATH"

          # Find or create the compatdata directory
          section "Setting up Wine Prefix"

          # Set up paths
          STEAMAPPS="''${AC_PATH%"/common/assettocorsa"}"

          # Check possible App IDs for Assetto Corsa
          POSSIBLE_APP_IDS=("244210" "244930")
          AC_COMPATDATA=""
          AC_APP_ID=""

          for app_id in "''${POSSIBLE_APP_IDS[@]}"; do
            if [[ -d "$STEAMAPPS/compatdata/$app_id" ]]; then
              AC_COMPATDATA="$STEAMAPPS/compatdata/$app_id"
              AC_APP_ID="$app_id"
              success "Found compatdata at $AC_COMPATDATA (App ID: $app_id)"
              break
            fi
          done

          if [[ -z "$AC_COMPATDATA" ]]; then
            warning "Could not find Assetto Corsa compatdata directory."
            echo "This script will use App ID 244210 as the default."
            AC_APP_ID="244210"
            AC_COMPATDATA="$STEAMAPPS/compatdata/$AC_APP_ID"
            ensure_dir "$AC_COMPATDATA"
            ensure_dir "$AC_COMPATDATA/pfx"
            ensure_dir "$AC_COMPATDATA/pfx/drive_c"
            warning "Created compatdata directory at $AC_COMPATDATA"
            warning "You'll need to launch Assetto Corsa at least once with Proton to complete setup."
          fi

          # Ensure the Wine prefix directory structure exists
          ensure_dir "$AC_COMPATDATA/pfx/drive_c/users/steamuser/Documents"
          ensure_dir "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local"
          ensure_dir "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Roaming"
          ensure_dir "$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config"

          # Create symlink for Content Manager
          link_from="$STEAM_PATH/config/loginusers.vdf"
          link_to="$AC_COMPATDATA/pfx/drive_c/Program Files (x86)/Steam/config/loginusers.vdf"

          if [[ -f "$link_from" ]]; then
            ln -sf "$link_from" "$link_to"
            success "Created Steam config symlink for Content Manager"
          else
            warning "Could not find Steam config file to symlink"
          fi

          # Check for running Assetto Corsa process
          ac_pid="$(pgrep "AssettoCorsa.ex" || echo "")"
          if [[ -n "$ac_pid" ]]; then
            warning "Assetto Corsa is running. It needs to be closed to proceed."
            if ask "Stop Assetto Corsa?"; then
              kill "$ac_pid"
              success "Stopped Assetto Corsa process"
            else
              error "Cannot proceed while Assetto Corsa is running"
              exit 1
            fi
          fi

          # Main menu
          while true; do
            section "Main Menu"
            echo "1. Install/Update Content Manager"
            echo "2. Fix Content Manager Paths"
            echo "3. Install Custom Shaders Patch (CSP)"
            echo "4. Install DXVK (recommended for AMD GPUs)"
            echo "5. Check for problematic shortcuts"
            echo "6. Reset Assetto Corsa to original (remove Content Manager)"
            echo "7. Show setup information"
            echo "0. Exit"

            read -p "Enter your choice: " menu_choice

            case $menu_choice in
              1)
                # Install/Update Content Manager
                section "Installing Content Manager"

                # Create temp directory
                rm -rf temp
                mkdir -p temp

                echo "Downloading Content Manager..."
                ${pkgs.wget}/bin/wget -q "https://acstuff.club/app/latest.zip" -P "temp/" || error "Failed to download Content Manager"
                ${pkgs.unzip}/bin/unzip -q "temp/latest.zip" -d "temp/" || error "Failed to extract Content Manager"

                # Replace Assetto Corsa executable with Content Manager
                if [[ -f "temp/Content Manager.exe" ]]; then
                  mv "temp/Content Manager.exe" "temp/AssettoCorsa.exe"
                  if [[ -f "$AC_PATH/AssettoCorsa_original.exe" ]]; then
                    rm -f "$AC_PATH/AssettoCorsa.exe"
                  else
                    mv "$AC_PATH/AssettoCorsa.exe" "$AC_PATH/AssettoCorsa_original.exe"
                  fi
                  cp "temp/AssettoCorsa.exe" "$AC_PATH/" || error "Failed to copy Content Manager exe"
                  success "Installed Content Manager executable"
                else
                  error "Content Manager exe not found in downloaded files"
                fi

                # Install fonts required for CM
                echo "Installing fonts for Content Manager..."
                ${pkgs.wget}/bin/wget -q "https://files.acstuff.ru/shared/T0Zj/fonts.zip" -P "temp/" || error "Failed to download fonts"
                ${pkgs.unzip}/bin/unzip -qo "temp/fonts.zip" -d "temp/" || error "Failed to extract fonts"

                ensure_dir "$AC_PATH/content/fonts/"
                cp -r "temp/system" "$AC_PATH/content/fonts/" || error "Failed to copy fonts"
                success "Installed fonts for Content Manager"

                # Fix CM paths right after installation
                CM_CONFIG_DIR="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
                ensure_dir "$CM_CONFIG_DIR"

                # Create settings.ini with the correct AC path
                WINE_AC_PATH="Z:$AC_PATH"
                SETTINGS_FILE="$CM_CONFIG_DIR/settings.ini"

                if [[ -f "$SETTINGS_FILE" ]]; then
                  # Backup existing settings
                  cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
                  # Update AC path in existing file
                  sed -i "s|assettoCorsaPath=.*|assettoCorsaPath=$WINE_AC_PATH|" "$SETTINGS_FILE"
                else
                  # Create minimal settings.ini if it doesn't exist
                  cat > "$SETTINGS_FILE" << EOF
[General]
assettoCorsaPath=$WINE_AC_PATH
EOF
                fi
                success "Set Assetto Corsa path in Content Manager settings"

                # Clean up
                rm -rf temp
                success "Content Manager installation completed!"
                ;;

              2)
                # Fix Content Manager Paths
                section "Fixing Content Manager Paths"

                CM_CONFIG_DIR="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
                ensure_dir "$CM_CONFIG_DIR"

                # Create settings.ini with the correct AC path
                WINE_AC_PATH="Z:$AC_PATH"
                echo "Setting Assetto Corsa path to: $WINE_AC_PATH"

                SETTINGS_FILE="$CM_CONFIG_DIR/settings.ini"

                if [[ -f "$SETTINGS_FILE" ]]; then
                  # Backup existing settings
                  cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
                  success "Backed up existing settings to $SETTINGS_FILE.backup"

                  # Update AC path in existing file
                  sed -i "s|assettoCorsaPath=.*|assettoCorsaPath=$WINE_AC_PATH|" "$SETTINGS_FILE"
                else
                  # Create minimal settings.ini if it doesn't exist
                  cat > "$SETTINGS_FILE" << EOF
[General]
assettoCorsaPath=$WINE_AC_PATH
EOF
                fi

                success "Content Manager path fixed!"
                echo "In Content Manager, if it still asks for the Assetto Corsa location, navigate to:"
                echo "$AC_PATH"
                ;;

              3)
                # Install Custom Shaders Patch
                section "Installing Custom Shaders Patch"

                # Create temp directory
                rm -rf temp
                mkdir -p temp

                # Check for existing CSP installation
                data_manifest_file="$AC_PATH/extension/config/data_manifest.ini"
                current_CSP_version=""

                if [[ -f "$data_manifest_file" ]]; then
                  current_CSP_version="$(cat "$data_manifest_file" | grep "SHADERS_PATCH=" | sed 's/SHADERS_PATCH=//g')"
                  if [[ -n "$current_CSP_version" ]]; then
                    echo "Current CSP version: $current_CSP_version"
                  fi
                fi

                echo "Will install CSP version ${cspVersion}"

                # Create user.reg if it doesn't exist
                touch "$AC_COMPATDATA/pfx/user.reg"

                # Create DLL override in user.reg
                echo 'Adding "dwrite" DLL override...'
                if ! grep -q "dwrite" "$AC_COMPATDATA/pfx/user.reg"; then
                  echo '"dwrite"="native,builtin"' >> "$AC_COMPATDATA/pfx/user.reg"
                  success "Added DLL override for dwrite"
                else
                  success "DLL override for dwrite already exists"
                fi

                # Download and install CSP
                echo "Downloading CSP..."
                ${pkgs.wget}/bin/wget -q "https://acstuff.club/patch/?get=${cspVersion}" -P "temp/" || error "Failed to download CSP"

                # Rename and extract CSP
                mv "temp/index.html?get=${cspVersion}" "temp/lights-patch-v${cspVersion}.zip" -f
                ${pkgs.unzip}/bin/unzip -qo "temp/lights-patch-v${cspVersion}.zip" -d "temp/" || error "Failed to extract CSP"

                # Copy CSP files
                cp -r "temp/." "$AC_PATH" || error "Failed to copy CSP files"
                success "Installed CSP files"

                # Install corefonts
                echo "Installing required fonts (this might take a while)..."
                WINEPREFIX="$AC_COMPATDATA/pfx" ${pkgs.winetricks}/bin/winetricks -q corefonts || warning "Could not install corefonts. Some text in CSP might not display correctly."

                # Clean up
                rm -rf temp
                success "CSP installation completed!"
                ;;

              4)
                # Install DXVK
                section "Installing DXVK"

                echo "Installing DXVK..."
                WINEPREFIX="$AC_COMPATDATA/pfx" ${pkgs.winetricks}/bin/winetricks -q dxvk || error "Could not install DXVK"
                success "DXVK installation completed!"
                ;;

              5)
                # Check for problematic shortcuts
                section "Checking for problematic shortcuts"

                STARTMENU_LINK="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Content Manager.lnk"

                if [[ -f "$STARTMENU_LINK" ]]; then
                  warning "Found Start Menu shortcut that might cause crashes"
                  if ask "Delete the Start Menu shortcut?"; then
                    rm -f "$STARTMENU_LINK"
                    success "Start Menu shortcut deleted"
                  else
                    echo "Shortcut not deleted"
                  fi
                else
                  success "No problematic Start Menu shortcuts found"
                fi
                ;;

              6)
                # Reset Assetto Corsa to original
                section "Resetting Assetto Corsa"

                if [[ -f "$AC_PATH/AssettoCorsa_original.exe" ]]; then
                  if ask "This will restore the original Assetto Corsa executable, removing Content Manager. Continue?"; then
                    rm -f "$AC_PATH/AssettoCorsa.exe"
                    mv "$AC_PATH/AssettoCorsa_original.exe" "$AC_PATH/AssettoCorsa.exe"
                    success "Restored original Assetto Corsa executable"
                  fi
                else
                  error "Could not find original Assetto Corsa executable"
                fi
                ;;

              7)
                # Show setup information
                section "Setup Information"

                echo "Steam Path: $STEAM_PATH"
                echo "Assetto Corsa Path: $AC_PATH"
                echo "Compatdata Path: $AC_COMPATDATA"
                echo "App ID: $AC_APP_ID"

                echo ""
                echo "Content Manager Status:"
                if [[ -f "$AC_PATH/AssettoCorsa_original.exe" ]]; then
                  success "Content Manager is installed"
                else
                  echo "Content Manager is not installed"
                fi

                echo ""
                echo "CSP Status:"
                data_manifest_file="$AC_PATH/extension/config/data_manifest.ini"
                if [[ -f "$data_manifest_file" ]]; then
                  current_CSP_version="$(cat "$data_manifest_file" | grep "SHADERS_PATCH=" | sed 's/SHADERS_PATCH=//g')"
                  if [[ -n "$current_CSP_version" ]]; then
                    success "CSP version $current_CSP_version is installed"
                  else
                    echo "CSP data_manifest.ini exists but no version found"
                  fi
                else
                  echo "CSP is not installed"
                fi

                echo ""
                echo "DXVK Status:"
                if grep -q "dxgi=native" "$AC_COMPATDATA/pfx/user.reg" 2>/dev/null; then
                  success "DXVK appears to be installed"
                else
                  echo "DXVK does not appear to be installed"
                fi
                ;;

              0)
                section "Exiting"
                echo "Thank you for using the Assetto Corsa Setup Tool!"
                exit 0
                ;;

              *)
                warning "Invalid choice. Please try again."
                ;;
            esac

            echo ""
            read -p "Press Enter to continue..."
          done
        '';

      in {
        packages = {
          default = assettocorsa-tool;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = assettocorsa-tool;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Core dependencies
            wget
            unzip
            gnutar

            # Wine and related tools
            wine
            winetricks

            # The setup tool itself
            assettocorsa-tool
          ];

          shellHook = ''
            echo "Assetto Corsa Setup Tool Environment"
            echo "Run 'assettocorsa-tool' to start the interactive setup menu"
          '';
        };
      }
    );
}
