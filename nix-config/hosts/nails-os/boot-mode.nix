# Stub — overwritten by the Calamares installer at install time.
# Provides EFI boot as the safe default so the flake evaluates cleanly
# before installation.
_: {
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
    grub.enable = false;
  };
}
