# flake.nix
# Distributable Assetto Corsa Setup Tool for NixOS
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

                    # Function to handle Content Manager path configuration
                    configure_cm_path() {
                      local cm_config_dir="$1"
                      local wine_ac_path="$2"

                      ensure_dir "$cm_config_dir"

                      # Update settings.ini
                      local settings_file="$cm_config_dir/settings.ini"
                      if [[ -f "$settings_file" ]]; then
                        # Backup existing settings
                        cp "$settings_file" "$settings_file.backup"
                        # Update AC path in existing file
                        sed -i "s|assettoCorsaPath=.*|assettoCorsaPath=$wine_ac_path|" "$settings_file"
                      else
                        # Create minimal settings.ini if it doesn't exist
                        cat > "$settings_file" << EOF
          [General]
          assettoCorsaPath=$wine_ac_path
          EOF
                      fi
                      success "Updated settings.ini with Assetto Corsa path"

                      # Update data.json if it exists
                      local data_json="$cm_config_dir/data.json"
                      if [[ -f "$data_json" ]]; then
                        # Create a backup
                        cp "$data_json" "$data_json.backup"

                        # Update JSON with correct path
                        if command -v jq >/dev/null 2>&1; then
                          # Use jq if available
                          cat "$data_json" | jq --arg path "$wine_ac_path" '.assettoCorsaFolder = $path' > "$data_json.tmp"
                          mv "$data_json.tmp" "$data_json"
                          success "Updated data.json with Assetto Corsa path (using jq)"
                        else
                          # Simple search/replace if jq is not available
                          sed -i 's|"assettoCorsaFolder": ".*"|"assettoCorsaFolder": "'$wine_ac_path'"|' "$data_json"
                          success "Updated data.json with Assetto Corsa path (simple method)"
                        fi
                      fi
                    }

                    # Function for aggressive CM path fixing
                    force_cm_path_update() {
                      local wine_prefix="$1"
                      local ac_path="$2"
                      local wine_ac_path="$3"

                      echo "Performing aggressive Content Manager path configuration..."

                      # 1. Force update all possible CM config locations
                      local cm_config_locations=(
                        "$wine_prefix/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
                        "$wine_prefix/drive_c/users/steamuser/Application Data/AcTools Content Manager"
                        "$wine_prefix/drive_c/users/Public/Application Data/AcTools Content Manager"
                        "$wine_prefix/drive_c/users/Public/Documents/AcTools Content Manager"
                      )

                      for cm_dir in "''${cm_config_locations[@]}"; do
                        if [[ -d "$cm_dir" ]] || mkdir -p "$cm_dir"; then
                          echo "Updating paths in $cm_dir"

                          # 1a. Update settings.ini with multiple path formats
                          cat > "$cm_dir/settings.ini" << EOF
          [General]
          assettoCorsaPath=$wine_ac_path
          assettoCorsaFolder=$wine_ac_path
          EOF
                          chmod 777 "$cm_dir/settings.ini"

                          # 1b. Force JSON config if it exists
                          if [[ -f "$cm_dir/data.json" ]]; then
                            mv "$cm_dir/data.json" "$cm_dir/data.json.bak"
                          fi

                          # Create simple data.json with the path
                          cat > "$cm_dir/data.json" << EOF
          {
            "assettoCorsaFolder": "$wine_ac_path",
            "steamFolder": "Z:$HOME/.local/share/Steam",
            "pathsSet": true
          }
          EOF
                          chmod 777 "$cm_dir/data.json"
                        fi
                      done

                      # 2. Create multiple registry entries using different methods
                      local reg_temp="$wine_prefix/drive_c/ac_path.reg"

                      # Windows backslash path for registry
                      local win_ac_path=$(echo "$wine_ac_path" | sed 's|/|\\\\|g')

                      cat > "$reg_temp" << EOF
          Windows Registry Editor Version 5.00

          [HKEY_CURRENT_USER\\Software\\Wine\\Drives]
          "z:"="/"

          [HKEY_CURRENT_USER\\Software\\Assetto Corsa]
          "InstallDir"="$win_ac_path"
          "Path"="$win_ac_path"

          [HKEY_LOCAL_MACHINE\\Software\\Assetto Corsa]
          "InstallDir"="$win_ac_path"
          "Path"="$win_ac_path"

          [HKEY_CURRENT_USER\\Software\\Kunos Simulazioni\\Assetto Corsa]
          "INSTALLDIR"="$win_ac_path"
          EOF

                      # Try multiple ways to import the registry
                      echo "Importing registry with Assetto Corsa paths..."
                      WINEPREFIX="$wine_prefix" wine regedit "$reg_temp" 2>/dev/null
                      WINEPREFIX="$wine_prefix" wine cmd /c "regedit /s C:\\ac_path.reg" 2>/dev/null

                      # 3. Create a direct symlink to ensure CM can find AC
                      if [[ ! -L "$wine_prefix/drive_c/assettocorsa" ]]; then
                        ln -sf "$ac_path" "$wine_prefix/drive_c/assettocorsa"
                        echo "Created symlink at $wine_prefix/drive_c/assettocorsa"
                      fi

                      # 4. Create a small config launcher
                      cat > "$wine_prefix/drive_c/cm_path_fix.bat" << EOF
          @echo off
          reg add "HKCU\\Software\\Assetto Corsa" /v "InstallDir" /t REG_SZ /d "$win_ac_path" /f
          reg add "HKLM\\Software\\Assetto Corsa" /v "InstallDir" /t REG_SZ /d "$win_ac_path" /f
          reg add "HKCU\\Software\\Kunos Simulazioni\\Assetto Corsa" /v "INSTALLDIR" /t REG_SZ /d "$win_ac_path" /f
          echo Assetto Corsa path set to $win_ac_path
          pause
          EOF

                      echo "Aggressive path configuration completed."
                    }

                    # Function for improved DXVK installation
                    install_dxvk() {
                      local wine_prefix="$1"

                      section "Installing DXVK"

                      echo "Installing DXVK using manual DLL overrides..."

                      # Create user.reg if it doesn't exist
                      touch "$wine_prefix/user.reg"

                      # Define the DLLs that need to be overridden for DXVK
                      local dxvk_dlls=("d3d9" "d3d10" "d3d10core" "d3d10_1" "d3d11" "dxgi")

                      # Add DLL overrides directly to the user.reg file
                      for dll in "''${dxvk_dlls[@]}"; do
                        echo "Adding override for $dll..."
                        if ! grep -q "\"$dll\"=" "$wine_prefix/user.reg"; then
                          echo "\"$dll\"=\"native,builtin\"" >> "$wine_prefix/user.reg"
                        else
                          # Update existing entry
                          sed -i "s/\"$dll\"=.*/\"$dll\"=\"native,builtin\"/" "$wine_prefix/user.reg"
                        fi
                      done

                      # Download latest DXVK release
                      mkdir -p temp/dxvk
                      echo "Downloading latest DXVK release..."

                      # Get the latest DXVK release URL
                      DXVK_VERSION="1.10.3"  # Specify a known good version
                      DXVK_URL="https://github.com/doitsujin/dxvk/releases/download/v''${DXVK_VERSION}/dxvk-''${DXVK_VERSION}.tar.gz"

                      if ${pkgs.wget}/bin/wget -q "$DXVK_URL" -O "temp/dxvk.tar.gz"; then
                        ${pkgs.gnutar}/bin/tar -xzf "temp/dxvk.tar.gz" -C "temp/dxvk" --strip-components=1

                        # Copy DLL files to the system32 and syswow64 directories
                        ensure_dir "$wine_prefix/drive_c/windows/system32"
                        ensure_dir "$wine_prefix/drive_c/windows/syswow64"

                        echo "Installing 64-bit DXVK DLLs..."
                        cp temp/dxvk/x64/*.dll "$wine_prefix/drive_c/windows/system32/" 2>/dev/null || \
                          warning "Could not copy 64-bit DLLs"

                        echo "Installing 32-bit DXVK DLLs..."
                        cp temp/dxvk/x32/*.dll "$wine_prefix/drive_c/windows/syswow64/" 2>/dev/null || \
                          warning "Could not copy 32-bit DLLs"

                        success "DXVK DLLs installed successfully"

                        # Create a d3d11.txt setup file in the Assetto Corsa directory to enable DXVK
                        cat > "$AC_PATH/d3d11.txt" << EOF
          enabled=1
          EOF
                        success "Enabled D3D11 mode for Assetto Corsa"

                        success "DXVK installation completed!"
                      else
                        error "Failed to download DXVK. Please check your internet connection."
                        warning "You can try installing DXVK through Proton by setting it in Steam's game properties."
                      fi

                      # Clean up
                      rm -rf temp/dxvk temp/dxvk.tar.gz
                    }

                    # Check for a pre-configured Assetto Corsa path
                    check_preconfigured_path() {
                      CONFIG_FILE="$HOME/.config/assettocorsa-nixos-setup/config.ini"

                      if [[ -f "$CONFIG_FILE" ]]; then
                        # Read preconfigured path
                        PRECONFIGURED_PATH=$(grep "AC_PATH=" "$CONFIG_FILE" | cut -d'=' -f2)

                        if [[ -n "$PRECONFIGURED_PATH" && -d "$PRECONFIGURED_PATH" ]]; then
                          success "Using pre-configured Assetto Corsa path: $PRECONFIGURED_PATH"
                          return 0
                        fi
                      fi

                      return 1
                    }

                    # Save a path to the configuration file
                    save_path_to_config() {
                      CONFIG_DIR="$HOME/.config/assettocorsa-nixos-setup"
                      CONFIG_FILE="$CONFIG_DIR/config.ini"

                      # Create config directory if it doesn't exist
                      ensure_dir "$CONFIG_DIR"

                      # Write or update the path
                      if [[ -f "$CONFIG_FILE" ]]; then
                        # Update existing config
                        sed -i "s|^AC_PATH=.*$|AC_PATH=$1|" "$CONFIG_FILE" 2>/dev/null || echo "AC_PATH=$1" >> "$CONFIG_FILE"
                      else
                        # Create new config
                        echo "AC_PATH=$1" > "$CONFIG_FILE"
                      fi

                      success "Saved Assetto Corsa path to configuration: $1"
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

                    # Check if we have a pre-configured path
                    if check_preconfigured_path; then
                      AC_PATH="$PRECONFIGURED_PATH"
                    else
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

                      # Save the path for future use
                      save_path_to_config "$AC_PATH"
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

                    # Define the Content Manager config dir variable outside case blocks to avoid scope issues
                    CM_CONFIG_DIR="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
                    # Define the Wine-style AC path variable - both forward slash and backslash versions
                    WINE_AC_PATH="Z:$AC_PATH"
                    WINE_AC_PATH_BS="Z:\\$(echo "$AC_PATH" | sed 's|/|\\\\|g')"

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
                      echo "8. Set or change Assetto Corsa path"
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
                          configure_cm_path "$CM_CONFIG_DIR" "$WINE_AC_PATH"

                          # Apply aggressive path fixing
                          echo "Applying aggressive path fixing methods..."
                          force_cm_path_update "$AC_COMPATDATA/pfx" "$AC_PATH" "$WINE_AC_PATH"

                          # Clean up
                          rm -rf temp
                          success "Content Manager installation completed!"
                          ;;

                        2)
                          # Fix Content Manager Paths
                          section "Fixing Content Manager Paths"

                          echo "Setting Assetto Corsa path to: $WINE_AC_PATH"
                          configure_cm_path "$CM_CONFIG_DIR" "$WINE_AC_PATH"

                          # Apply aggressive path fixing
                          echo "Applying aggressive path fixing methods..."
                          force_cm_path_update "$AC_COMPATDATA/pfx" "$AC_PATH" "$WINE_AC_PATH"

                          success "Content Manager path fixed!"
                          echo "If Content Manager still asks for the Assetto Corsa location, navigate to:"
                          echo "$AC_PATH"
                          echo ""
                          echo "You can also try the alternative path format:"
                          echo "$WINE_AC_PATH_BS"
                          echo ""
                          echo "Or simply point it to drive_c/assettocorsa within the Wine prefix"
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
                          # Install DXVK using the improved method
                          install_dxvk "$AC_COMPATDATA/pfx"
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

                          # Show Wine path format
                          echo "Wine Path (for Content Manager): $WINE_AC_PATH"
                          echo "Alternative Wine Path: $WINE_AC_PATH_BS"

                          echo ""
                          echo "Content Manager Status:"
                          if [[ -f "$AC_PATH/AssettoCorsa_original.exe" ]]; then
                            success "Content Manager is installed"
                          else
                            echo "Content Manager is not installed"
                          fi

                          echo ""
                          echo "Content Manager Path Configuration:"
                          SETTINGS_FILE="$CM_CONFIG_DIR/settings.ini"
                          if [[ -f "$SETTINGS_FILE" ]]; then
                            AC_PATH_IN_SETTINGS=$(grep "assettoCorsaPath=" "$SETTINGS_FILE" | cut -d'=' -f2)
                            if [[ "$AC_PATH_IN_SETTINGS" == "$WINE_AC_PATH" ]]; then
                              success "Content Manager path is correctly configured in settings.ini"
                            else
                              warning "Content Manager path is not correctly configured in settings.ini"
                              echo "  Current: $AC_PATH_IN_SETTINGS"
                              echo "  Should be: $WINE_AC_PATH"
                            fi
                          else
                            warning "Content Manager settings.ini file not found"
                          fi

                          echo ""
                          echo "If you need to manually configure Content Manager, use these exact values:"
                          echo "  Assetto Corsa path: $WINE_AC_PATH"
                          echo "  Alternative path format: $WINE_AC_PATH_BS"
                          echo "  Or try the symlink at: C:\\assettocorsa"

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
                          if grep -q "d3d11=native" "$AC_COMPATDATA/pfx/user.reg" 2>/dev/null; then
                            success "DXVK appears to be installed"
                            if [[ -f "$AC_PATH/d3d11.txt" ]]; then
                              success "D3D11 mode is enabled for Assetto Corsa"
                            else
                              warning "D3D11 mode is not enabled for Assetto Corsa"
                              if ask "Enable D3D11 mode now?"; then
                                echo "enabled=1" > "$AC_PATH/d3d11.txt"
                                success "D3D11 mode enabled"
                              fi
                            fi
                          else
                            echo "DXVK does not appear to be installed"
                          fi
                          ;;

                        8)
                          # Set or change Assetto Corsa path
                          section "Set or Change Assetto Corsa Path"

                          echo "Current Assetto Corsa path: $AC_PATH"
                          echo "Enter new path to Assetto Corsa directory:"
                          read -i "$AC_PATH" -e NEW_AC_PATH

                          # Expand ~ to $HOME
                          NEW_AC_PATH="$(echo "$NEW_AC_PATH" | sed "s|\~\/|$HOME\/|g")"

                          # Check if the path exists and is valid
                          if [[ -d "$NEW_AC_PATH" ]]; then
                            if [[ -f "$NEW_AC_PATH/AssettoCorsa.exe" || -f "$NEW_AC_PATH/AssettoCorsa_original.exe" ]]; then
                              # Save the new path
                              save_path_to_config "$NEW_AC_PATH"

                              # Update the current path
                              AC_PATH="$NEW_AC_PATH"
                              STEAMAPPS="$(dirname "$(dirname "$AC_PATH")")"
                              WINE_AC_PATH="Z:$AC_PATH"
                              WINE_AC_PATH_BS="Z:\\$(echo "$AC_PATH" | sed 's|/|\\\\|g')"

                              # Ask to update Content Manager paths
                              if ask "Do you want to update Content Manager paths to use this new location?"; then
                                configure_cm_path "$CM_CONFIG_DIR" "$WINE_AC_PATH"

                                # Apply aggressive path fixing with the new path
                                echo "Applying aggressive path fixing methods..."
                                force_cm_path_update "$AC_COMPATDATA/pfx" "$AC_PATH" "$WINE_AC_PATH"

                                success "Updated Content Manager settings with new path"
                              fi
                            else
                              error "The selected directory does not appear to be an Assetto Corsa installation"
                              echo "It should contain AssettoCorsa.exe or AssettoCorsa_original.exe"
                            fi
                          else
                            error "The selected directory does not exist: $NEW_AC_PATH"
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

      in
      {
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
            jq # Added jq for JSON manipulation

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
