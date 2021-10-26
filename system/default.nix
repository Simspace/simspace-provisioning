{ lib, pkgs, ... }:

let
  try = builtins.tryEval <simspace-custom>;
  custom = if try.success then [try.value] else [];
  provided = if pkgs.stdenv.isDarwin then ./darwin.nix else ./linux.nix;
in {
  imports = [provided] ++ custom;
}
