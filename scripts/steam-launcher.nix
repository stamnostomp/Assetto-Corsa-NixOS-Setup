# scripts/steam-launcher.nix
# Setting up Steam launch options for Assetto Corsa

{ pkgs, utils }:

''
  # Setup Steam launch options
  setup_steam_launch_options() {
    section "Setting Up Steam Launch Options"

    echo "Steam launch options are crucial for getting DXVK working properly."
    echo "You've confirmed that these options work for your system:"
    echo ""
    echo "DXVK_HUD=full WINEPREFIX=\"$AC_COMPATDATA/pfx\" %command%"
    echo ""

    # Create a helper script that opens Steam directly to Assetto Corsa properties
    echo "Creating a helper script to set Assetto Corsa launch options in Steam..."

    # Get the app ID
    app_id="244210"
    if [ -n "$AC_APP_ID" ]; then
      app_id="$AC_APP_ID"
    fi

    # Create the script
    cat > "$AC_PATH/set_steam_launch_options.sh" << EOF
  #!/bin/bash
  # Helper script to set Assetto Corsa launch options in Steam

  # Kill any running Steam instances
  pkill -f steam || true
  sleep 1

  # Launch Steam and navigate to Assetto Corsa properties
  steam "steam://open/properties/$app_id"

  echo ""
  echo "✓ Steam should now be opening to Assetto Corsa properties."
  echo ""
  echo "Instructions:"
  echo "1. In the properties window, click on 'GENERAL'"
  echo "2. Look for 'LAUNCH OPTIONS' at the bottom"
  echo "3. Copy and paste this exact text:"
  echo ""
  echo "DXVK_HUD=full WINEPREFIX=\"$AC_COMPATDATA/pfx\" %command%"
  echo ""
  echo "4. Click 'OK' to save the changes"
  echo ""
  echo "After setting the launch options, you can launch Assetto Corsa directly from Steam."
  EOF
    chmod +x "$AC_PATH/set_steam_launch_options.sh"
    success "Created helper script at $AC_PATH/set_steam_launch_options.sh"

    # Create a launcher script that just adds the environment variables
    echo "Creating an alternative launch script for Steam..."
    cat > "$AC_PATH/launch_ac_steam.sh" << EOF
  #!/bin/bash
  # Launch Assetto Corsa with DXVK environment variables
  # Add this to Steam launch options: "$AC_PATH/launch_ac_steam.sh" %command%

  export DXVK_HUD=full
  export WINEPREFIX="$AC_COMPATDATA/pfx"

  # Launch the original command
  exec "\$@"
  EOF
    chmod +x "$AC_PATH/launch_ac_steam.sh"
    success "Created Steam launcher script at $AC_PATH/launch_ac_steam.sh"

    # Offer to run the helper script
    echo ""
    echo "Would you like to run the helper script now to set up Steam launch options?"
    if ask "Open Steam to Assetto Corsa properties?"; then
      "$AC_PATH/set_steam_launch_options.sh"
    else
      echo "You can run the script later with:"
      echo "$AC_PATH/set_steam_launch_options.sh"
    fi

    # Provide alternative method
    echo ""
    echo "Alternative method:"
    echo "You can use the launch_ac_steam.sh script in Steam launch options instead:"
    echo ""
    echo "\"$AC_PATH/launch_ac_steam.sh\" %command%"
    echo ""
    echo "This achieves the same effect but keeps the environment variables in a separate script."

    echo ""
    section "Additional Steam Configuration Tips"

    echo "For optimal performance with DXVK and Proton GE:"
    echo ""
    echo "1. In Steam, right-click on Assetto Corsa > Properties"
    echo "2. Under Compatibility, check 'Force the use of a specific Steam Play compatibility tool'"
    echo "3. Select Proton GE from the dropdown (recommended: Proton-GE-9-25)"
    echo "4. Make sure the launch options are set as described above"
    echo "5. Click 'Play' to launch the game with these settings"
    echo ""
    echo "You should see the DXVK HUD (showing FPS and other metrics) when the game runs,"
    echo "confirming that DXVK is working properly."
  }
''
