{ config ? import ./config.nix
, buildSet ? config.build.set
, buildInfrastructure ? config.build.infrastructure
, checkMaterialization ? config.infrastructure.haskell-nix.checkMaterialization
}:

let
  nix = import ./external { inherit config; };

  bootstrap = import nix.nixpkgs-stable {
    config = {}; overlays = [];
  };

  gitIgnores = []; #TODO check for gitIgnores to add later

  sources =
    let
      gi = bootstrap.nix-gitignore;
    in nix // {
      simspace-provisioning = gi.gitignoreSource gitIgnores ./.;
    };

  infra = import ./infra {
    inherit checkMaterialization sources;
    infraConfig = config.infrastructure;
    isDevBuild = config.build.dev;
  };

  myPkgs = import ./packages.nix infra;
  updateMaterialized = myPkgs.haskell-nix.updateMaterialized;

  includeSet = bs: buildSet == bs || buildSet == "all";
  includeInfra = i: buildInfrastructure == i || buildInfrastructure == "all";
  include = bs: i: ps:
      if includeSet bs && includeInfra i then ps else {};

  selectedPkgs =
    (   include "prebuilt" "nixpkgs"     myPkgs.nixpkgs.prebuilt)
    // (include "prebuilt" "haskell-nix" myPkgs.haskell-nix.prebuilt);

  pkgs = infra.np.nixpkgs-stable.recurseIntoAttrs selectedPkgs;

in { inherit infra pkgs sources updateMaterialized; }
