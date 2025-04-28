# scripts/main.nix
# Main script that ties everything together

{
  pkgs,
  utils,
  contentManager,
  csp,
  dxvk,
  diagnostics,
  wine64Fix,
  steamLauncher,
  cmUiFix,
}:

''
  #!/usr/bin/env bash

  ${utils}
  ${contentManager}
  ${csp}
  ${dxvk}
  ${diagnostics}
  ${wine64Fix}
  ${steamLauncher}
  ${cmUiFix}

  # Banner
  echo -e "''${BLUE}''${BOLD}"
  echo "╔═══════════════════════════════════════════════════╗"
  echo "║       Assetto Corsa Setup Tool for NixOS          ║"
  echo "╚═══════════════════════════════════════════════════╝"
  echo -e "''${NC}"

  # Print system information
  section "System Information"
  echo "Date: $(date)"
  echo "User: $USER"
  echo "Hostname: $(hostname)"
  echo "NixOS: $(nixos-version 2>/dev/null || echo "Not NixOS or command not found")"

  # Setup paths for Steam, Assetto Corsa, etc.
  setup_paths

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
    echo "9. Force DXVK installation (use if normal install fails)"
    echo "10. Run advanced diagnostics and fixes"
    echo "11. Fix Wine 64-bit compatibility (for black screens)"
    echo "12. Setup Steam launch options"
    echo "13. Fix Content Manager UI black boxes"
    echo "0. Exit"

    read -p "Enter your choice: " menu_choice

    case $menu_choice in
      1)
        install_content_manager
        ;;
      2)
        fix_content_manager_paths
        ;;
      3)
        install_csp
        ;;
      4)
        install_dxvk
        ;;
      5)
        check_shortcuts
        ;;
      6)
        reset_assetto_corsa
        ;;
      7)
        show_setup_info
        ;;
      8)
        change_ac_path
        ;;
      9)
        install_dxvk "force"
        ;;
      10)
        run_diagnostics
        ;;
      11)
        fix_wine64_compatibility
        ;;
      12)
        setup_steam_launch_options
        ;;
      13)
        fix_cm_ui_rendering
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
''
