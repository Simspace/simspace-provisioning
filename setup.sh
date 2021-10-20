#!/bin/bash


main ()
{
  curl -L https://nixos.org/nix/install | sh
  curl -L https://github.com/Simspace/simspace-provisioning/archive/refs/heads/main.zip --output simspace-provisioning.zip
  unzip simspace-provisioning.zip
  mv simspace-provisioning-main simspace-provisioning
  rm -rf simspace-provisioning.zip
}

main "$@"
