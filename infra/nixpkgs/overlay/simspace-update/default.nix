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
        gnutar
        gzip
    ];
}
''
set -eu
set -o pipefail


NIX_EXE="$(command -v nix || true)"
NIXOS_EXE="$(command -v nixos-rebuild || true)"
USER=true
SYSTEM=true
UPDATE=true
REVISION=main
CACHE_DIR=~/.cache/simspace/provisioning
CHECKOUT="$CACHE_DIR/repo"
PROJECT_URL=git@github.com:Simspace/simspace-provisioning.git
ARGS=()


. "${self.nix-project-lib.common}/share/nix-project/common.bash"


print_usage()
{
    cat - <<EOF
USAGE:
    ${progName} [OPTION]...               [--] [switch]
    ${progName} [OPTION]... --user-only   [--] HOME_MANAGER_ARGS...
    ${progName} [OPTION]... --system-only [--] DARWIN_OR_NIXOS_REBUILD_ARGS...

DESCRIPTION:

    By default updates both system-level configuration and user
    home directory configuration to the latest curated by
    SimSpace Engineering.

OPTIONS:

    -h --help           print this help message

    -u --user-only      only provision user home directory
    -s --system-only    only provision system installation

    -U --no-update      don't update provisioning code
                        (ignores --revision)

    -r --revision ID    ID of branch/tag to use (else latest supported)

    -N --nix PATH       filepath of 'nix' executable to use
    -R --nixos-rebuild
                  PATH  filepath of 'nixos-rebuild' executable to use

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
        -u|--user-only)
            USER=false
            ;;
        -s|--system-only)
            SYSTEM=false
            ;;
        -U|--no-update)
            UPDATE=false
            ;;
        -r|--revision)
            if [ -z "''${2:-}" ]
            then die "$1 requires argument"
            fi
            REVISION="''${2:-}"
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

    if [ "''${#ARGS[@]}" -eq 0 ]
    then ARGS=(switch)
    fi

    echo "Adding nix executable to the Path..."
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
    echo "Checking for valid preconditions..."
    if "$USER" && "$SYSTEM"
    then
        for a in "''${ARGS[@]}"
        do
            if [ "$a" != switch ]
            then die "disallowed argument: $a"
            fi
        done
        if [ "''${#ARGS[@]}" -ne 1 ]
        then die "too many commands: ''${ARGS[*]}"
        fi
    fi
    if ! ( "$USER" || "$SYSTEM" )
    then die "--user-only and --system-only incompatible"
    fi
    echo "Configuring checkout directory..."
    local checkout_dir; checkout_dir="$(dirname "$CHECKOUT")"
    echo "Creating checkout directory..."
    if ! mkdir --parents "$checkout_dir"
    then die_helpless "could not create directory: $checkout_dir"
    fi
}

set_up_source()
{
    echo "Checking for existing project clone..."
    if ! [ -d "$CHECKOUT" ]
    then
        echo "Cloning project..."
        git clone -- "$PROJECT_URL" "$CHECKOUT"
    fi
    if "$UPDATE"
    then
        echo "Updating checkout..."
        git -C "$CHECKOUT" fetch --all --prune
        local id; id="$(revision_id)"
        if [ -z "$id" ]
        then die_helpless "bad revision: $REVISION"
        fi
        git -C "$CHECKOUT" checkout "$id"
    fi
}

provision_system()
{
    echo "Provisioning for system level configuration..."
    if [ "$(uname)" = "Darwin" ]
    then provision_darwin
    else provision_linux
    fi
}

provision_darwin()
{
    echo "Provisioning Mac system..."
    nix run \
        --ignore-environment \
        --keep HOME \
        --file "$CHECKOUT" \
        infra.np.nixpkgs-stable.simspace-darwin-rebuild \
        --command \
        simspace-darwin-rebuild \
        --nix "$NIX_EXE" \
        "''${ARGS[@]}"
}

provision_linux()
{
    echo "Provisioning Linux system..."
    nix run \
        --ignore-environment \
        --keep HOME \
        --file "$CHECKOUT" \
        infra.np.nixpkgs-stable.simspace-nixos-rebuild \
        --command \
        simspace-nixos-rebuild \
        --nix "$NIXOS_EXE" \
        "''${ARGS[@]}"
}

provision_user()
{
    echo "Provisioning for user level configuration..."
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
        "''${ARGS[@]}"
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
