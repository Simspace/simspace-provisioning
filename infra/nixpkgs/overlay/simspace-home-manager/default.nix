self: _super:

let
    progName = "simspace-home-manager";
    meta.description = "Controlled home directory management with Nix";
    sources = (import ../../../.. {}).sources;
in

self.nix-project-lib.writeShellCheckedExe progName
{
    inherit meta;
    path = with self; [
        coreutils
        git
        gnugrep
        gnutar
        gzip
        hostname
        home-manager
    ];
}
''
set -eu
set -o pipefail


NIX_EXE="$(command -v nix || true)"
ARGS=()


. "${self.nix-project-lib.common}/share/nix-project/common.bash"


print_usage()
{
    cat - <<EOF
USAGE: ${progName} [OPTION]... [--] HOME_MANAGER_ARGS...

DESCRIPTION:

    A wrapper of home-manager that heavily controls environment
    variables, including NIX_PATH.  Unrecognized switches and
    arguments are passed through to home-manager.

OPTIONS:

    -h --help         print this help message
    -N --nix PATH     filepath of 'nix' executable to use

    '${progName}' pins all dependencies except for Nix itself,
     which it finds on the path if possible.  Otherwise set
     '--nix'.

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
        -N|--nix)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            NIX_EXE="''${2:-}"
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
    then manage "''${ARGS[@]}"
    else manage build
    fi
}

manage()
{
    local config="${sources.simspace-provisioning}/user"
    local custom="$HOME/.config/simspace/provisioning/user"
    add_nix_to_path "$NIX_EXE"
    /usr/bin/env -i \
        HOME="$HOME" \
        PATH="$PATH" \
        TERM="$TERM" \
        DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-}" \
        TERMINFO="''${TERMINFO:-}" \
        USER="$USER" \
        NIX_PATH="nixpkgs=${sources.nixpkgs-home}:simspace-custom=$custom" \
        home-manager -f "$config" "$@"
}


main "$@"
''
