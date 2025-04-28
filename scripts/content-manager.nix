# scripts/content-manager.nix
# Content Manager installation and configuration

{ pkgs, utils }:

''
  # Install or update Content Manager
  install_content_manager() {
    section "Installing Content Manager"

    setup_temp_dir

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
    fix_content_manager_paths

    success "Content Manager installation completed!"
  }

  # Fix Content Manager paths
  fix_content_manager_paths() {
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
  }

  # Check for problematic shortcuts
  check_shortcuts() {
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
  }

  # Reset Assetto Corsa to original
  reset_assetto_corsa() {
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
  }

  # Set or change Assetto Corsa path
  change_ac_path() {
    section "Set or Change Assetto Corsa Path"

    echo "Current Assetto Corsa path: $AC_PATH"
    echo "Enter new path to Assetto Corsa directory:"
    read -i "$HOME/" -e NEW_AC_PATH

    # Expand ~ to $HOME
    NEW_AC_PATH="$(echo "''${NEW_AC_PATH%"/"}" | sed "s|\~\/|$HOME\/|g")"

    if [[ ! -d "$NEW_AC_PATH" ]]; then
      error "Invalid directory: $NEW_AC_PATH"
    else
      AC_PATH="$NEW_AC_PATH"
      success "Set Assetto Corsa path to: $AC_PATH"

      # Update steamapps path
      if [[ "$AC_PATH" =~ /steamapps/common/assettocorsa$ ]]; then
        STEAMAPPS="''${AC_PATH%"/common/assettocorsa"}"
        success "Updated steamapps path to: $STEAMAPPS"

        # Re-detect compatdata
        for app_id in "''${POSSIBLE_APP_IDS[@]}"; do
          if [[ -d "$STEAMAPPS/compatdata/$app_id" ]]; then
            AC_COMPATDATA="$STEAMAPPS/compatdata/$app_id"
            AC_APP_ID="$app_id"
            success "Found compatdata at $AC_COMPATDATA (App ID: $app_id)"
            break
          fi
        done
      else
        warning "Custom path doesn't follow Steam standard structure"
        warning "Some features might not work correctly"
      fi

      # Update Content Manager path if needed
      if [[ -n "$AC_COMPATDATA" ]]; then
        CM_CONFIG_DIR="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
        if [[ -d "$CM_CONFIG_DIR" ]]; then
          SETTINGS_FILE="$CM_CONFIG_DIR/settings.ini"
          WINE_AC_PATH="Z:$AC_PATH"

          if [[ -f "$SETTINGS_FILE" ]]; then
            sed -i "s|assettoCorsaPath=.*|assettoCorsaPath=$WINE_AC_PATH|" "$SETTINGS_FILE"
            success "Updated Content Manager path to: $WINE_AC_PATH"
          fi
        fi
      fi
    fi
  }
''
