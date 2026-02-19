_: {
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.amnesia = import ../home/amnesia.nix;
  };
}
