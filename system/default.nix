{ lib, ... }:

let
  try = builtins.tryEval <simspace-custom>;
  custom = if try.success then [try.value] else [];
in {
  imports = [./provided.nix] ++ custom;
}
