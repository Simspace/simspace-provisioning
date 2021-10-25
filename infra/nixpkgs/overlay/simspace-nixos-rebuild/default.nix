self: _super:

let
    progName = "simspace-nixos-rebuild";
    meta.description = "Controlled NixOS rebuild";
    sources = (import ../../../.. {}).sources;
in

self.nix-project-lib.writeShellCheckedExe progName
{
    inherit meta;
    path = with self; [
        coreutils
        hostname
        man_db
    ];
}
''
set -eu
set -o pipefail


NIXOS_EXE="$(command -v nixos-rebuild || true)"
ARGS=()


. "${self.nix-project-lib.common}/share/nix-project/common.bash"


print_usage()
{
    cat - <<EOF
USAGE: ${progName} [OPTION]... [--] NIXOS_REBUILD_ARGS...

DESCRIPTION:

    A wrapper of nixos-rebuild that isolates Nixpkgs and NixOS
    configuration to pinned versions.  Unrecognized switches and
    arguments are passed through to nixos-rebuild.

OPTIONS:

    -h --help                print this help message
    -N --nixos-rebuild PATH  filepath of 'nixos-rebuild'
                             executable to use

    '${progName}' pins all dependencies except for Nix itself,
     which it finds on the path if possible.  Otherwise set
     '--nixos-exe'.

EOF
}


main()
{
    while ! [ "''${1:-}" = "" ]
    do
        case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -N|--nixos-rebuild)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            NIXOS_EXE="''${2:-}"
            shift
            ;;
        --)
            shift
            ARGS+=("$@")
            break
            ;;
        *)
            ARGS+=("$1")
            ;;
        esac
        shift
    done
    if [ "''${#ARGS[@]}" -gt 0 ]
    then rebuild "''${ARGS[@]}"
    else rebuild build
    fi
}

rebuild()
{
    local config="${sources.simspace-provisioning}/system"
    local custom="$HOME/.config/simspace/provisioning/system"
    /usr/bin/env -i \
        MANPATH=/run/current-system/sw/share/man \
        PATH="$(path_for "$NIXOS_EXE"):$PATH" \
        NIX_PATH="nixpkgs=${sources.nixpkgs-system}:simspace-custom=$custom" \
        NIXOS_CONFIG="$config" \
        nixos-rebuild "$@"
}


main "$@"
''
