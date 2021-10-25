self: _super:

let
    progName = "simspace-update";
    meta.description = "SimSpace system and user update script";
    sources = (import ../../../.. {}).sources;
in

self.nix-project-lib.writeShellCheckedExe progName
{
    inherit meta;
    path = with self; [
        coreutils
        git
        hostname
    ];
}
''
set -eu
set -o pipefail


TARGET="$(hostname)"
NIX_EXE="$(command -v nix || true)"
NIXOS_EXE="$(command -v nixos-rebuild || true)"
USER=true
SYSTEM=true
REVISION=main
CACHE_DIR=~/.cache/simspace/provisioning
CONFIG_DIR=~/.config/simspace/provisioning
CHECKOUT="$CACHE_DIR/repo"
PROJECT_URL=git@github.com:Simspace/simspace-provisioning.git

. "${self.nix-project-lib.common}/share/nix-project/common.bash"


print_usage()
{
    cat - <<EOF
USAGE: ${progName} [OPTION]... [--] NIX_DARWIN_ARGS...

DESCRIPTION:

    By default updates both system-level configuration and user
    home directory configuration to the latest curated by
    SimSpace Engineering.

OPTIONS:

    -h --help                print this help message

    -u --user                provision user home directory (default)
    -U --no-user             don't provision user home directory
    -s --system              provision system installation (default)
    -S --no-system           don't provision system installation

    -r --revision ID         ID of branch/tag to use (else latest supported)

    -t --target NAME         target host to configure for
                             (otherwise autodetected)

    -N --nix PATH            filepath of 'nix' executable to use
    -R --nixos-rebuild PATH  filepath of 'nixos-rebuild' executable to use

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
        -u|--user)
            USER=true
            ;;
        -U|--no-user)
            USER=false
            ;;
        -s|--system)
            SYSTEM=true
            ;;
        -S|--no-system)
            SYSTEM=false
            ;;
        -r|--revision)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            REVISION="''${2:-}"
            shift
            ;;
        -t|--target)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            TARGET="''${2:-}"
            shift
            ;;
        -N|--nix)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            NIX_EXE="''${2:-}"
            shift
            ;;
        -R|--nixos-rebuild)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            NIXOS_EXE="''${2:-}"
            shift
            ;;
        *)
            die "unrecognized argument: $1"
            ;;
        esac
        shift
    done

    add_nix_to_path "$NIX_EXE"

    check_preconditions
    set_up_source
    if "$SYSTEM"
    then provision_system
    fi
    if "$USER"
    then provision_user
    fi
    echo
    echo "SUCCESS: Finished provisioning"
}

check_preconditions()
{
    local checkout_dir; checkout_dir="$(dirname "$CHECKOUT")"
    if ! mkdir --parents "$checkout_dir"
    then die_helpless "could not create directory: $checkout_dir"
    fi
}

set_up_source()
{
    if ! [ -d "$CHECKOUT" ]
    then git clone -- "$PROJECT_URL" "$CHECKOUT"
    fi
    git -C "$CHECKOUT" fetch --all --prune
    local id; id="$(revision_id)"
    if [ -z "$id" ]
    then die_helpless "bad revision: $REVISION"
    fi
    git -C "$CHECKOUT" checkout "$id"
}

provision_system()
{
    if [ "$(uname)" = "Darwin" ]
    then provision_darwin
    else provision_linux
    fi
}

provision_darwin()
{
    nix run \
        --ignore-environment \
        --file "$CHECKOUT" \
        infra.np.nixpkgs-stable.simspace-darwin-rebuild \
        --command \
        simspace-darwin-rebuild \
        --nix "$NIX_EXE" \
        "$@"
}

provision_linux()
{
    nix run \
        --ignore-environment \
        --file "$CHECKOUT" \
        infra.np.nixpkgs-stable.simspace-nixos-rebuild \
        --command \
        simspace-nixos-rebuild \
        --nix "$NIXOS_EXE" \
        "$@"
}

provision_user()
{
    nix run \
        --ignore-environment \
        --keep DBUS_SESSION_BUS_ADDRESS \
        --keep HOME \
        --keep TERM \
        --keep TERMINFO \
        --keep USER \
        --file "$CHECKOUT" \
        infra.np.nixpkgs-stable.simspace-home-manager \
        --command \
        simspace-home-manager \
        --nix "$NIX_EXE" \
        "$@"
}

revision_id()
{
    if   git -C "$CHECKOUT" rev-parse "origin/$REVISION" 2>/dev/null 1>&2
    then git -C "$CHECKOUT" rev-parse "origin/$REVISION" 2>/dev/null
    elif git -C "$CHECKOUT" rev-parse "$REVISION" 2>/dev/null 1>&2
    then git -C "$CHECKOUT" rev-parse "$REVISION" 2>/dev/null
    fi
}


main "$@"
''
