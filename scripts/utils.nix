# scripts/utils.nix
# Utility functions shared across all scripts

{ pkgs }:

''
  # Color setup
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m'

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

  # Steam and Assetto Corsa path setup function
  setup_paths() {
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

    # Export paths for other scripts
    export STEAM_PATH
    export AC_PATH
    export STEAMAPPS
    export AC_COMPATDATA
    export AC_APP_ID
  }

  # Function to create a temp directory and clean it up when done
  setup_temp_dir() {
    rm -rf temp
    mkdir -p temp
    trap "rm -rf temp" EXIT
  }

  # Function to modify Wine registry
  modify_wine_registry() {
    local reg_file="$1"
    local key="$2"
    local value="$3"

    # Check if registry file exists
    if [[ ! -f "$reg_file" ]]; then
      touch "$reg_file"
    fi

    # Make a backup if it doesn't exist yet
    if [[ ! -f "$reg_file.backup" ]]; then
      cp "$reg_file" "$reg_file.backup"
      success "Created backup of $reg_file"
    fi

    # Check if key exists and update it, or add it if it doesn't exist
    if grep -q "$key" "$reg_file"; then
      sed -i "s|$key=.*|$key=$value|" "$reg_file"
    else
      echo "$key=$value" >> "$reg_file"
    fi

    success "Updated registry key: $key"
  }

  # Function to show detailed setup information
  show_setup_info() {
    section "Setup Information"

    echo "Steam Path: $STEAM_PATH"
    echo "Assetto Corsa Path: $AC_PATH"
    echo "Compatdata Path: $AC_COMPATDATA"
    echo "App ID: $AC_APP_ID"

    # Additional WINE paths for Content Manager
    echo "Wine Path (for Content Manager): Z:$AC_PATH"
    echo "Alternative Wine Path: Z:\\\\home\\\\$USER\\\\.local\\\\share\\\\Steam\\\\steamapps\\\\common\\\\assettocorsa"

    echo ""
    echo "Content Manager Status:"
    if [[ -f "$AC_PATH/AssettoCorsa_original.exe" ]]; then
      success "Content Manager is installed"
    else
      echo "Content Manager is not installed"
    fi

    # Check Content Manager settings
    CM_CONFIG_DIR="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
    SETTINGS_FILE="$CM_CONFIG_DIR/settings.ini"
    if [[ -f "$SETTINGS_FILE" ]]; then
      success "Content Manager settings file exists"
      if grep -q "assettoCorsaPath=" "$SETTINGS_FILE"; then
        success "Content Manager path is correctly configured in settings.ini"
      else
        warning "Content Manager path not found in settings.ini"
      fi
    else
      echo "Content Manager settings file not found"
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
    dxvk_status=false

    # Check for multiple possible DXVK entries
    if grep -q "dxgi=.*native" "$AC_COMPATDATA/pfx/user.reg" 2>/dev/null ||
       grep -q "d3d11=.*native" "$AC_COMPATDATA/pfx/user.reg" 2>/dev/null; then
      success "DXVK appears to be installed"
      dxvk_status=true
    else
      echo "DXVK does not appear to be installed"
    fi

    # Show detailed DXVK information if installed
    if [[ "$dxvk_status" == "true" ]]; then
      echo "DXVK DLL overrides:"
      for dll in d3d9 d3d10 d3d10_1 d3d10core d3d11 dxgi; do
        reg_entry=$(grep -i "\"$dll\"=" "$AC_COMPATDATA/pfx/user.reg" 2>/dev/null || echo "Not set")
        echo "  - $dll: $reg_entry"
      done
    fi

    echo ""
    if ask "Would you like to see the full user.reg file?"; then
      echo "Content of user.reg:"
      cat "$AC_COMPATDATA/pfx/user.reg" || echo "Could not read user.reg"
    fi
  }
''
