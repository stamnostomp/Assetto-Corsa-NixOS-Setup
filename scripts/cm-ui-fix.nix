# scripts/cm-ui-fix.nix
# Fix for Content Manager UI black box issues

{ pkgs, utils }:

''
  # Fix Content Manager UI rendering issues
  fix_cm_ui_rendering() {
    section "Fixing Content Manager UI Rendering Issues"

    echo "This fix addresses issues with black boxes in Content Manager UI,"
    echo "particularly in menus and when clicking the hamburger menu button."

    # Find Content Manager settings file
    CM_CONFIG_DIR="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager"
    SETTINGS_FILE="$CM_CONFIG_DIR/settings.ini"

    if [ ! -f "$SETTINGS_FILE" ]; then
      warning "Content Manager settings file not found at $SETTINGS_FILE"
      echo "Please run Content Manager at least once to generate the settings file."
      return 1
    fi

    # Backup settings
    cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup"
    success "Created backup of Content Manager settings"

    # Add/modify UI rendering fixes
    echo "Applying UI rendering fixes to Content Manager settings..."

    # UI rendering fix 1: Disable hardware acceleration for UI
    if grep -q "hardwareAcceleration=" "$SETTINGS_FILE"; then
      sed -i "s/hardwareAcceleration=.*/hardwareAcceleration=False/" "$SETTINGS_FILE"
    else
      echo "hardwareAcceleration=False" >> "$SETTINGS_FILE"
    fi

    # UI rendering fix 2: Set DXGI wrapper mode
    if grep -q "dxgiWrapperMode=" "$SETTINGS_FILE"; then
      sed -i "s/dxgiWrapperMode=.*/dxgiWrapperMode=1/" "$SETTINGS_FILE"
    else
      echo "dxgiWrapperMode=1" >> "$SETTINGS_FILE"
    fi

    # UI rendering fix 3: Set appropriate Direct3D feature level
    if grep -q "direct3DFeatureLevel=" "$SETTINGS_FILE"; then
      sed -i "s/direct3DFeatureLevel=.*/direct3DFeatureLevel=0/" "$SETTINGS_FILE"
    else
      echo "direct3DFeatureLevel=0" >> "$SETTINGS_FILE"
    fi

    # UI rendering fix 4: Disable Direct3D debug mode if enabled
    if grep -q "enableD3D11Debug=True" "$SETTINGS_FILE"; then
      sed -i "s/enableD3D11Debug=True/enableD3D11Debug=False/" "$SETTINGS_FILE"
    fi

    # UI rendering fix 5: Set specific render mode for UI elements
    if grep -q "uiRenderMode=" "$SETTINGS_FILE"; then
      sed -i "s/uiRenderMode=.*/uiRenderMode=1/" "$SETTINGS_FILE"
    else
      echo "uiRenderMode=1" >> "$SETTINGS_FILE"
    fi

    # UI rendering fix 6: Adjust Direct3D limiter
    if grep -q "direct3DLimiter=" "$SETTINGS_FILE"; then
      sed -i "s/direct3DLimiter=.*/direct3DLimiter=60/" "$SETTINGS_FILE"
    else
      echo "direct3DLimiter=60" >> "$SETTINGS_FILE"
    fi

    success "Applied UI rendering fixes to Content Manager settings"

    # Create a helper script to restore original settings if needed
    cat > "$AC_PATH/restore_cm_ui_settings.sh" << EOF
  #!/bin/bash
  # Helper script to restore original Content Manager UI settings

  SETTINGS_FILE="$SETTINGS_FILE"
  BACKUP_FILE="$SETTINGS_FILE.backup"

  if [ -f "\$BACKUP_FILE" ]; then
    cp "\$BACKUP_FILE" "\$SETTINGS_FILE"
    echo "✓ Restored original Content Manager settings"
  else
    echo "✗ Backup file not found at \$BACKUP_FILE"
  fi
  EOF
    chmod +x "$AC_PATH/restore_cm_ui_settings.sh"

    echo ""
    echo "Settings have been modified to fix UI rendering issues."
    echo "Please restart Content Manager to apply the changes."
    echo ""
    echo "If these changes cause any problems, you can restore the original settings with:"
    echo "$AC_PATH/restore_cm_ui_settings.sh"

    # Optional: Create an additional helper script with alternative settings to try
    cat > "$AC_PATH/try_alternative_cm_settings.sh" << EOF
  #!/bin/bash
  # Helper script to try alternative Content Manager UI settings

  SETTINGS_FILE="$SETTINGS_FILE"

  # Make a backup if one doesn't exist
  if [ ! -f "\$SETTINGS_FILE.backup" ]; then
    cp "\$SETTINGS_FILE" "\$SETTINGS_FILE.backup"
    echo "✓ Created backup of Content Manager settings"
  fi

  echo "Applying alternative UI rendering settings..."

  # Alternative 1: Software rendering mode
  sed -i "s/hardwareAcceleration=.*/hardwareAcceleration=False/" "\$SETTINGS_FILE"
  sed -i "s/dxgiWrapperMode=.*/dxgiWrapperMode=2/" "\$SETTINGS_FILE"
  sed -i "s/uiRenderMode=.*/uiRenderMode=2/" "\$SETTINGS_FILE"
  sed -i "s/dxvk=.*/dxvk=True/" "\$SETTINGS_FILE"
  sed -i "s/direct3DFeatureLevel=.*/direct3DFeatureLevel=1/" "\$SETTINGS_FILE"

  echo "✓ Applied alternative settings. Please restart Content Manager."
  echo "If these settings don't work, you can restore the original with:"
  echo "$AC_PATH/restore_cm_ui_settings.sh"
  EOF
    chmod +x "$AC_PATH/try_alternative_cm_settings.sh"

    echo ""
    echo "If the first set of fixes doesn't resolve the black box issues,"
    echo "you can try an alternative configuration with:"
    echo "$AC_PATH/try_alternative_cm_settings.sh"

    echo ""
    echo "Additional tip: In Content Manager, go to Settings > System > Video"
    echo "and experiment with these options:"
    echo "- Uncheck 'Hardware acceleration'"
    echo "- Try different 'UI render mode' settings"
    echo "- Set 'Direct3D feature level' to 'Default'"
  }
''
