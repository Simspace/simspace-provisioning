{ lib, ... }:

let
  custom =
    lib.optional (builtins.pathExists <simspace-custom>) <simspace-custom>;

in {
  imports = [./provided.nix] ++ custom;
}
