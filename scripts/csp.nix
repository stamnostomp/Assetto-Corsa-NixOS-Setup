# scripts/csp.nix
# Custom Shaders Patch installation

{
  pkgs,
  utils,
  cspVersion,
}:

''
  # Install Custom Shaders Patch
  install_csp() {
    section "Installing Custom Shaders Patch"

    setup_temp_dir

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
    if ! grep -q "\"dwrite\"=" "$AC_COMPATDATA/pfx/user.reg"; then
      echo "\"dwrite\"=\"native,builtin\"" >> "$AC_COMPATDATA/pfx/user.reg"
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

    # Fix potential registry format issues
    # Ensure dwrite override is in the correct section
    if ! grep -q "\[Software\\\\Wine\\\\DllOverrides\]" "$AC_COMPATDATA/pfx/user.reg"; then
      echo "" >> "$AC_COMPATDATA/pfx/user.reg"
      echo "[Software\\Wine\\DllOverrides]" >> "$AC_COMPATDATA/pfx/user.reg"
      echo "#time=$(date +%s)" >> "$AC_COMPATDATA/pfx/user.reg"
    fi

    # Move dwrite override to the correct section if needed
    if grep -q "^\"dwrite\"=" "$AC_COMPATDATA/pfx/user.reg"; then
      line=$(grep "^\"dwrite\"=" "$AC_COMPATDATA/pfx/user.reg")
      sed -i "/^\"dwrite\"=/d" "$AC_COMPATDATA/pfx/user.reg"
      sed -i "/\[Software\\\\Wine\\\\DllOverrides\]/a $line" "$AC_COMPATDATA/pfx/user.reg"
    fi

    # Ensure dwrite entry in system.reg as well
    echo "Applying system registry modifications for CSP..."
    if [ -f "$AC_COMPATDATA/pfx/system.reg" ]; then
      if ! grep -q "\"dwrite\"=\"native" "$AC_COMPATDATA/pfx/system.reg"; then
        if grep -q "\[Software\\\\Wine\\\\DllOverrides\]" "$AC_COMPATDATA/pfx/system.reg"; then
          sed -i "/\[Software\\\\Wine\\\\DllOverrides\]/a \"dwrite\"=\"native,builtin\"" "$AC_COMPATDATA/pfx/system.reg"
        else
          echo "" >> "$AC_COMPATDATA/pfx/system.reg"
          echo "[Software\\Wine\\DllOverrides]" >> "$AC_COMPATDATA/pfx/system.reg"
          echo "#time=$(date +%s)" >> "$AC_COMPATDATA/pfx/system.reg"
          echo "\"dwrite\"=\"native,builtin\"" >> "$AC_COMPATDATA/pfx/system.reg"
        fi
      else
        sed -i "s/\"dwrite\"=.*$/\"dwrite\"=\"native,builtin\"/" "$AC_COMPATDATA/pfx/system.reg"
      fi
    fi

    # Force direct registry modification with reg files
    echo "Creating direct registry file for CSP overrides..."
    cat > "temp/csp_overrides.reg" << EOF
  REGEDIT4

  [HKEY_CURRENT_USER\\Software\\Wine\\DllOverrides]
  "dwrite"="native,builtin"
  EOF

    echo "Importing registry file..."
    WINEPREFIX="$AC_COMPATDATA/pfx" ${pkgs.wine}/bin/wine regedit "temp/csp_overrides.reg"

    # Verify CSP installation
    if [[ -f "$data_manifest_file" ]]; then
      new_CSP_version="$(cat "$data_manifest_file" | grep "SHADERS_PATCH=" | sed 's/SHADERS_PATCH=//g')"
      if [[ -n "$new_CSP_version" ]]; then
        success "CSP version $new_CSP_version installed successfully"
      else
        warning "CSP may not be installed correctly - no version info found"
      fi
    else
      warning "CSP data_manifest.ini not found - installation may have failed"
    fi

    success "CSP installation completed!"
  }
''
