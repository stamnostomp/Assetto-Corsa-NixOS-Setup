# scripts/wine64-fix.nix
# Wine 64-bit compatibility fix for Assetto Corsa, optimized for Proton GE

{ pkgs, utils }:

''
  # Fix Wine 64-bit compatibility issues
  fix_wine64_compatibility() {
    section "Wine 64-bit Compatibility Fix"

    setup_temp_dir

    # Verify the issue
    echo "Checking Wine prefix architecture..."
    is_64bit=false

    if [ -f "$AC_COMPATDATA/pfx/system.reg" ]; then
      if grep -q "#arch=win64" "$AC_COMPATDATA/pfx/system.reg"; then
        echo "Confirmed: Wine prefix is 64-bit"
        is_64bit=true
      else
        echo "Wine prefix is 32-bit"
        is_64bit=false
      fi
    else
      warning "Could not determine Wine prefix architecture"
      return 1
    fi

    if [ "$is_64bit" = "true" ]; then
      # Check if wine64 is available
      if ! command -v wine64 &> /dev/null && ! [ -x "${pkgs.wine}/bin/wine64" ]; then
        warning "No wine64 executable found in PATH or in Nix package"
        echo "We need to ensure 64-bit Wine is available for your 64-bit prefix"

        # NixOS-specific solution
        if [ -f /etc/os-release ] && grep -q "ID=nixos" /etc/os-release; then
          echo "For NixOS, add the following to your configuration.nix:"
          echo ""
          echo "  nixpkgs.config.allowUnfree = true;  # If using proprietary NVIDIA drivers"
          echo "  environment.systemPackages = with pkgs; ["
          echo "    (wineWowPackages.stable.override { wineBuild = \"wine64\"; })"
          echo "  ];"
          echo ""
          echo "Then run 'sudo nixos-rebuild switch'"
        else
          echo "For non-NixOS systems, we'll create a wrapper script to use a 64-bit Wine"
        fi

        # Create a wrapper for Content Manager using Proton's wine64
        echo "Creating a wrapper script to use Proton's wine64 for Content Manager..."

        # Find available Proton installations with preference for GE
        proton_dirs=()
        proton_ge_dirs=()
        if [ -d "$STEAM_PATH/steamapps/common/" ]; then
          # First check for GE-Proton installations
          for dir in "$STEAM_PATH/steamapps/common/GE-Proton"* "$STEAM_PATH/steamapps/common/Proton-GE"*; do
            if [ -d "$dir" ] && [ -f "$dir/proton" ]; then
              proton_ge_dirs+=("$dir")
            fi
          done

          # Then check for standard Proton installations
          for dir in "$STEAM_PATH/steamapps/common/Proton"*; do
            if [[ "$dir" != *"GE-Proton"* && "$dir" != *"Proton-GE"* ]] && [ -d "$dir" ] && [ -f "$dir/proton" ]; then
              proton_dirs+=("$dir")
            fi
          done
        fi

        # Combine with GE installations first
        all_proton_dirs=("''${proton_ge_dirs[@]}" "''${proton_dirs[@]}")

        if [ ''${#all_proton_dirs[@]} -eq 0 ]; then
          warning "No Proton installations found. Please install Proton in Steam first."
          return 1
        fi

        # Use the latest Proton installation (preferring GE if available)
        latest_proton="''${all_proton_dirs[0]}"

        # Check if we're using GE-Proton
        using_ge=false
        if [[ "$latest_proton" == *"GE-Proton"* || "$latest_proton" == *"Proton-GE"* ]]; then
          success "Using Proton GE from: $latest_proton"
          using_ge=true
        else
          echo "Using standard Proton from: $latest_proton"
        fi

        # Different paths for Proton GE vs standard
        if [ "$using_ge" = true ]; then
          wine64_path="$latest_proton/files/bin/wine64"
          if [ ! -f "$wine64_path" ]; then
            # Try alternate path structure
            wine64_path="$latest_proton/dist/bin/wine64"
          fi
        else
          wine64_path="$latest_proton/dist/bin/wine64"
        fi

        # Verify the wine64 path
        if [ ! -f "$wine64_path" ]; then
          warning "Could not find wine64 in expected location: $wine64_path"
          echo "Searching for wine64 in Proton directory..."
          wine64_path=$(find "$latest_proton" -name "wine64" -type f -executable | head -n 1)

          if [ -z "$wine64_path" ]; then
            error "Could not find wine64 executable in Proton directory. Cannot continue."
            return 1
          fi

          success "Found wine64 at: $wine64_path"
        fi

        # Create launcher script
        cat > "$AC_PATH/run_cm_with_proton_wine64.sh" << EOF
  #!/bin/bash
  # Wrapper to run Content Manager using Proton's wine64

  # Set Wine environment
  export WINEPREFIX="$AC_COMPATDATA/pfx"
  export WINEDEBUG=+d3d,+d3d_shader,+dxgi
  export DXVK_HUD=full
  export DXVK_LOG_LEVEL=debug

  # Use Proton's wine64
  PROTON_WINE="$wine64_path"

  if [ ! -x "\$PROTON_WINE" ]; then
    echo "Error: Proton's wine64 not found or not executable!"
    echo "Expected location: \$PROTON_WINE"
    exit 1
  fi

  # Make sure we have all needed Proton libraries
  PROTON_LIB_PATH="\$(dirname "\$PROTON_WINE")/../lib64"
  if [ -d "\$PROTON_LIB_PATH" ]; then
    export LD_LIBRARY_PATH="\$PROTON_LIB_PATH:\$LD_LIBRARY_PATH"
  fi

  # For Proton GE specific environment
  if [ -f "$latest_proton/proton" ]; then
    # Source environment variables from Proton script if possible
    eval \$(grep "^export" "$latest_proton/proton" | grep -v "WINE=")
  fi

  echo "Starting Content Manager with Proton GE wine64..."
  echo "Location: \$PROTON_WINE"
  cd "$AC_PATH"
  "\$PROTON_WINE" "$AC_PATH/AssettoCorsa.exe" "\$@"
  EOF
        chmod +x "$AC_PATH/run_cm_with_proton_wine64.sh"
        success "Created launcher script at $AC_PATH/run_cm_with_proton_wine64.sh"

        echo ""
        echo "To use Content Manager with proper 64-bit Wine:"
        echo "1. Make sure you have Proton GE (or standard Proton) installed in Steam"
        echo "2. Run the script: $AC_PATH/run_cm_with_proton_wine64.sh"
        echo ""

        # Create a desktop entry file
        mkdir -p "$HOME/.local/share/applications"
        cat > "$HOME/.local/share/applications/assetto-corsa-cm.desktop" << EOF
  [Desktop Entry]
  Name=Assetto Corsa Content Manager
  Comment=Launch Assetto Corsa Content Manager with 64-bit Wine
  Exec=$AC_PATH/run_cm_with_proton_wine64.sh
  Icon=$AC_PATH/content/gui/mainmenu/icon.png
  Terminal=false
  Type=Application
  Categories=Game;
  EOF
        success "Created desktop shortcut: Assetto Corsa Content Manager"

        # Specific note for Proton GE
        if [ "$using_ge" = true ]; then
          echo ""
          echo "You're using Proton GE ($latest_proton), which is excellent for game compatibility!"
          echo "Proton GE includes optimized DXVK and many game-specific fixes."
        fi
      else
        success "64-bit Wine (wine64) is available on your system"
        echo "Your Wine prefix architecture is compatible with your Wine installation"

        # Still create a specialized launcher for better diagnostics
        cat > "$AC_PATH/run_cm_debug.sh" << EOF
  #!/bin/bash
  # Debug launcher for Content Manager

  # Set Wine environment
  export WINEPREFIX="$AC_COMPATDATA/pfx"
  export WINEDEBUG=+d3d,+d3d_shader,+dxgi
  export DXVK_HUD=full
  export DXVK_LOG_LEVEL=debug

  cd "$AC_PATH"
  wine64 "$AC_PATH/AssettoCorsa.exe" "\$@"
  EOF
        chmod +x "$AC_PATH/run_cm_debug.sh"
        success "Created debug launcher script at $AC_PATH/run_cm_debug.sh"
      fi
    else
      # 32-bit prefix
      echo "Your Wine prefix is 32-bit, which should work with standard Wine"
      echo "Creating a 32-bit specific launcher..."

      cat > "$AC_PATH/run_cm_32bit.sh" << EOF
  #!/bin/bash
  # 32-bit launcher for Content Manager

  # Set Wine environment
  export WINEPREFIX="$AC_COMPATDATA/pfx"
  export WINEDEBUG=+d3d,+d3d_shader,+dxgi
  export DXVK_HUD=full
  export DXVK_LOG_LEVEL=debug

  cd "$AC_PATH"
  wine "$AC_PATH/AssettoCorsa.exe" "\$@"
  EOF
      chmod +x "$AC_PATH/run_cm_32bit.sh"
      success "Created 32-bit launcher script at $AC_PATH/run_cm_32bit.sh"
    fi

    echo ""
    section "Additional Recommendations"

    echo "1. After launching Content Manager with the appropriate script, go to:"
    echo "   Settings > System > Video > DXVK (make sure it's enabled)"
    echo ""
    echo "2. If you see a DXVK overlay (FPS counter, etc.) when running the game, that means DXVK is working"
    echo ""
    echo "3. For Steam launch options, try:"
    if [ "$is_64bit" = "true" ]; then
      if [[ -n "$wine64_path" ]]; then
        proton_bin_dir=$(dirname "$wine64_path")
        echo "   WINEPREFIX=\"$AC_COMPATDATA/pfx\" DXVK_HUD=full PATH=\"$proton_bin_dir:\$PATH\" %command%"
      else
        echo "   WINEPREFIX=\"$AC_COMPATDATA/pfx\" DXVK_HUD=full %command%"
      fi
    else
      echo "   WINEPREFIX=\"$AC_COMPATDATA/pfx\" DXVK_HUD=full %command%"
    fi
  }
''
