# scripts/diagnostics.nix
# Advanced diagnostics and repair for Assetto Corsa setup

{ pkgs, utils }:

''
  # Run advanced diagnostics and repair
  run_diagnostics() {
    section "Advanced Diagnostics and Repair"

    setup_temp_dir

    # System checks
    echo "Checking system configuration..."
    echo "Wine version: $(${pkgs.wine}/bin/wine --version 2>/dev/null || echo 'Not found')"
    echo "Winetricks version: $(${pkgs.winetricks}/bin/winetricks --version 2>/dev/null || echo 'Not found')"
    echo "Graphics info:"
    ${pkgs.vulkan-tools}/bin/vulkaninfo --summary 2>/dev/null || echo "Vulkan tools not found or Vulkan not supported"
    echo "GL renderer: $(${pkgs.glxinfo}/bin/glxinfo | grep "OpenGL renderer" || echo "glxinfo not found")"

    # Check if this is NixOS
    if [ -f /etc/os-release ]; then
      if grep -q "ID=nixos" /etc/os-release; then
        echo "System is NixOS"
        # Print NixOS configuration information
        NIX_PATH=$(echo $NIX_PATH)
        echo "NIX_PATH: $NIX_PATH"
      else
        echo "System is not NixOS"
      fi
    fi

    # Check for common issues
    echo ""
    echo "Checking for common issues..."

    # 1. Check Wine architecture compatibility
    if [ -f "$AC_COMPATDATA/pfx/system.reg" ]; then
      if grep -q "#arch=win64" "$AC_COMPATDATA/pfx/system.reg"; then
        echo "Wine prefix is 64-bit"
        # Check if we're running a 64-bit wine
        if ! ${pkgs.wine}/bin/wine64 --version &>/dev/null; then
          warning "64-bit Wine not found but prefix is 64-bit. This will cause issues."
        else
          success "Wine architecture matches prefix"
        fi
      else
        echo "Wine prefix is 32-bit"
        # Check if we're running a 32-bit wine
        if ! ${pkgs.wine}/bin/wine --version &>/dev/null; then
          warning "32-bit Wine not found but prefix is 32-bit. This will cause issues."
        else
          success "Wine architecture matches prefix"
        fi
      fi
    else
      warning "Cannot determine Wine prefix architecture"
    fi

    # 2. Check for Vulkan support
    echo ""
    echo "Checking Vulkan support..."
    if ${pkgs.vulkan-tools}/bin/vulkaninfo --summary &>/dev/null; then
      success "Vulkan is properly supported on your system"
    else
      warning "Vulkan support may be missing or incomplete. This will affect DXVK performance."
      echo "Recommended action: Install appropriate Vulkan drivers for your GPU"

      # Try to determine GPU vendor
      if ${pkgs.glxinfo}/bin/glxinfo | grep -i "vendor" | grep -i "nvidia" &>/dev/null; then
        echo "NVIDIA GPU detected. Make sure to install nvidia-drivers with Vulkan support."
      elif ${pkgs.glxinfo}/bin/glxinfo | grep -i "vendor" | grep -i "amd\|ati" &>/dev/null; then
        echo "AMD GPU detected. Make sure to install amdvlk or RADV Vulkan drivers."
      elif ${pkgs.glxinfo}/bin/glxinfo | grep -i "vendor" | grep -i "intel" &>/dev/null; then
        echo "Intel GPU detected. Make sure to install Intel Vulkan drivers (ANV)."
      fi
    fi

    # 3. Check DXVK status with direct DLL inspection
    echo ""
    echo "Checking DXVK DLL status..."
    dxvk_dlls=0

    # Check if DLLs are present in system32 directory
    if [ -d "$AC_COMPATDATA/pfx/drive_c/windows/system32" ]; then
      echo "Checking DLLs in windows/system32:"
      for dll in d3d9.dll d3d10.dll d3d10_1.dll d3d10core.dll d3d11.dll dxgi.dll; do
        if [ -f "$AC_COMPATDATA/pfx/drive_c/windows/system32/$dll" ]; then
          dxvk_dlls=$((dxvk_dlls + 1))
          success "Found $dll"
        else
          warning "$dll not found"
        fi
      done

      if [ "$dxvk_dlls" -eq 6 ]; then
        success "All DXVK DLLs found in system32"
      else
        warning "Some DXVK DLLs are missing from system32 ($dxvk_dlls/6 found)"
      fi
    else
      warning "system32 directory not found in Wine prefix"
    fi

    # 4. Emergency direct DXVK installation
    echo ""
    echo "Would you like to perform an emergency direct DXVK installation?"
    echo "This will download and directly place DXVK DLLs in your Wine prefix."
    echo "This method bypasses winetricks and registry settings."

    if ask "Perform emergency DXVK installation?"; then
      echo "Downloading DXVK 1.10.3 (recommended for Assetto Corsa)..."
      ${pkgs.wget}/bin/wget -q "https://github.com/doitsujin/dxvk/releases/download/v1.10.3/dxvk-1.10.3.tar.gz" -P "temp/" || error "Failed to download DXVK"

      echo "Extracting DXVK..."
      ${pkgs.gnutar}/bin/tar -xzf "temp/dxvk-1.10.3.tar.gz" -C "temp/" || error "Failed to extract DXVK"

      echo "Installing DXVK DLLs directly..."
      if [ -d "$AC_COMPATDATA/pfx/drive_c/windows/system32" ]; then
        # Check for 64-bit prefix
        if grep -q "#arch=win64" "$AC_COMPATDATA/pfx/system.reg"; then
          echo "Installing 64-bit DXVK DLLs..."
          cp "temp/dxvk-1.10.3/x64/"*.dll "$AC_COMPATDATA/pfx/drive_c/windows/system32/" || warning "Failed to copy 64-bit DLLs"
        else
          echo "Installing 32-bit DXVK DLLs..."
          cp "temp/dxvk-1.10.3/x32/"*.dll "$AC_COMPATDATA/pfx/drive_c/windows/system32/" || warning "Failed to copy 32-bit DLLs"
        fi

        success "DXVK DLLs installed directly"
      else
        error "Cannot find system32 directory for DLL installation"
      fi

      # Create launcher script with DXVK_HUD=full
      echo "Creating Content Manager launcher script with DXVK_HUD=full..."
      cat > "$AC_PATH/run_cm_with_dxvk.sh" << EOF
  #!/bin/bash
  export DXVK_HUD=full
  export DXVK_LOG_LEVEL=debug
  cd "$AC_PATH"
  WINEPREFIX="$AC_COMPATDATA/pfx" ${pkgs.wine}/bin/wine "$AC_PATH/AssettoCorsa.exe" "\$@"
  EOF
      chmod +x "$AC_PATH/run_cm_with_dxvk.sh"
      success "Created launcher script at $AC_PATH/run_cm_with_dxvk.sh"
      echo "You can run Content Manager with full DXVK debugging using this script"
    fi

    # 5. Setup script for Steam launch options
    echo ""
    echo "Creating helper script for Steam launch options..."
    cat > "$AC_PATH/set_dxvk_env.sh" << EOF
  #!/bin/bash
  # Place this in Steam launch options:
  # DXVK_HUD=full WINEPREFIX="$AC_COMPATDATA/pfx" %command%
  export DXVK_HUD=full
  export DXVK_LOG_LEVEL=debug
  "\$@"
  EOF
    chmod +x "$AC_PATH/set_dxvk_env.sh"
    success "Created helper script at $AC_PATH/set_dxvk_env.sh"

    echo ""
    echo "Steam launch options:"
    echo "DXVK_HUD=full WINEPREFIX=\"$AC_COMPATDATA/pfx\" %command%"
    echo ""
    echo "Add these to your Assetto Corsa launch options in Steam"

    # 6. Check for potential conflicts
    echo ""
    echo "Checking for potential conflicts..."

    # Check for conflicting DLLs in the override directory
    if [ -d "$AC_COMPATDATA/pfx/drive_c/windows/system32" ]; then
      problematic=false
      for dll in d3d9.dll.old d3d10.dll.old d3d11.dll.old dxgi.dll.old; do
        if [ -f "$AC_COMPATDATA/pfx/drive_c/windows/system32/$dll" ]; then
          warning "Found potential conflicting file: $dll"
          problematic=true
        fi
      done

      if [ "$problematic" = true ]; then
        if ask "Remove potentially conflicting .old DLL files?"; then
          rm -f "$AC_COMPATDATA/pfx/drive_c/windows/system32/"*.dll.old
          success "Removed conflicting .old files"
        fi
      else
        success "No conflicting .old DLL files found"
      fi
    fi

    # 7. Fix potential graphics issues in Content Manager
    echo ""
    echo "Checking for potential Content Manager graphics fixes..."

    if [ -f "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager/settings.ini" ]; then
      cm_settings="$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager/settings.ini"

      # Create backup if needed
      if [ ! -f "$cm_settings.backup" ]; then
        cp "$cm_settings" "$cm_settings.backup"
        success "Created backup of Content Manager settings"
      fi

      # Check/fix graphics settings
      if ! grep -q "dxvk=" "$cm_settings"; then
        echo "dxvk=True" >> "$cm_settings"
        success "Enabled DXVK in Content Manager settings"
      elif grep -q "dxvk=False" "$cm_settings"; then
        sed -i "s/dxvk=False/dxvk=True/" "$cm_settings"
        success "Changed DXVK setting from False to True"
      fi

      # Other potential fixes
      if ! grep -q "videMemorySize=" "$cm_settings"; then
        # Try to detect video memory size
        vram=$(${pkgs.glxinfo}/bin/glxinfo | grep "Video memory" | head -n1 | grep -o '[0-9]\+' | head -n1)
        if [ -n "$vram" ]; then
          echo "videMemorySize=$vram" >> "$cm_settings"
          success "Set video memory size to $vram MB"
        else
          echo "videMemorySize=4096" >> "$cm_settings"
          success "Set default video memory size to 4096 MB"
        fi
      fi

      if ! grep -q "enableD3D11Debug=" "$cm_settings"; then
        echo "enableD3D11Debug=True" >> "$cm_settings"
        success "Enabled D3D11 debug mode"
      fi
    else
      warning "Content Manager settings file not found"
    fi

    # Provide a summary of findings and recommendations
    echo ""
    section "Diagnostics Summary"

    if [ "$dxvk_dlls" -lt 6 ]; then
      echo "❌ DXVK DLLs: Not all DLLs are present"
    else
      echo "✅ DXVK DLLs: All DLLs are present"
    fi

    # Check Vulkan support again
    if ${pkgs.vulkan-tools}/bin/vulkaninfo --summary &>/dev/null; then
      echo "✅ Vulkan support: Available"
    else
      echo "❌ Vulkan support: Not available (required for DXVK)"
    fi

    # Check if wine is compatible
    if [ -f "$AC_COMPATDATA/pfx/system.reg" ]; then
      if grep -q "#arch=win64" "$AC_COMPATDATA/pfx/system.reg"; then
        if ${pkgs.wine}/bin/wine64 --version &>/dev/null; then
          echo "✅ Wine compatibility: 64-bit Wine available for 64-bit prefix"
        else
          echo "❌ Wine compatibility: 64-bit Wine not available for 64-bit prefix"
        fi
      else
        if ${pkgs.wine}/bin/wine --version &>/dev/null; then
          echo "✅ Wine compatibility: 32-bit Wine available for 32-bit prefix"
        else
          echo "❌ Wine compatibility: 32-bit Wine not available for 32-bit prefix"
        fi
      fi
    fi

    # Check Content Manager settings
    if [ -f "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager/settings.ini" ]; then
      if grep -q "dxvk=True" "$AC_COMPATDATA/pfx/drive_c/users/steamuser/AppData/Local/AcTools Content Manager/settings.ini"; then
        echo "✅ Content Manager: DXVK enabled in settings"
      else
        echo "❌ Content Manager: DXVK not enabled in settings"
      fi
    else
      echo "❓ Content Manager: Settings file not found"
    fi

    # Final recommendations
    echo ""
    echo "Recommendations:"
    echo "1. Try running Content Manager with the created script: $AC_PATH/run_cm_with_dxvk.sh"
    echo "2. Set Steam launch options to: DXVK_HUD=full WINEPREFIX=\"$AC_COMPATDATA/pfx\" %command%"
    echo "3. If graphics issues persist, try a different Proton version (like Proton-GE)"
    echo "4. Make sure your graphics drivers are up to date with Vulkan support"

    # For NixOS specific recommendations
    if [ -f /etc/os-release ] && grep -q "ID=nixos" /etc/os-release; then
      echo ""
      echo "NixOS-specific recommendations:"
      echo "1. Ensure you have hardware.opengl.driSupport and hardware.opengl.driSupport32Bit enabled"
      echo "2. For NVIDIA: hardware.nvidia.modesetting.enable = true"
      echo "3. For Vulkan: hardware.opengl.extraPackages = [ pkgs.vulkan-loader pkgs.vulkan-validation-layers ]"
    fi
  }
''
