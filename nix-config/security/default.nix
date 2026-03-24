{ pkgs, target, ignoredCvesFile }:

pkgs.callPackage ./vulnix-scan.nix { inherit target ignoredCvesFile; }
