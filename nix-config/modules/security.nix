_: {
  security.apparmor.enable = true;

  boot = {
    kernelModules = [ "overlay" ];
    blacklistedKernelModules = [
      "firewire_core"
      "firewire_ohci"
      "thunderbolt"
      "usb4"
    ];
    kernelParams = [
      "init_on_free=1"
      "init_on_alloc=1"
      "slab_nomerge"
      "slub_debug=FZ"
      "vsyscall=none"
      "mce=0"
      "page_alloc.shuffle=1"
      "randomize_kstack_offset=on"
      "mds=full,nosmt"
      "spec_store_bypass_disable=on"
    ];
    kernel.sysctl = {
      "kernel.kexec_load_disabled" = 1;
      "net.core.bpf_jit_harden" = 2;
    };
  };

  services.haveged.enable = true;

  # Disable swap to avoid data persistence; use encrypted swap only if explicitly enabled.
  swapDevices = [ ];
  zramSwap.enable = false;
}
