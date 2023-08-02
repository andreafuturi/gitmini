#!/bin/sh

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

xdg_bin_home="${XDG_BIN_HOME:-$HOME/.local/bin}"

APPLICATION_NAME="GitMini"

bin_name="gitmini"

configure_install_aliases() {
    commands="publish unpublish start refresh current pause combine update list rename delete"

    for cmd in $commands; do
        git config --global "alias.$cmd" "!${bin_name} $cmd"
        #  git config --global "alias.$cmd" "!$0 $cmd"
    done
}

# Function: install
#
# Install GitMini in $XDG_BIN_HOME and set up global aliases for the exposed commands.

configure_install() {
    _out_name="$1"

    if [ ! -e "$xdg_bin_home" ]; then
        mkdir -p "$xdg_bin_home"
    elif [ ! -d "$xdg_bin_home" ]; then
        printf "${RED}error: %s is not a directory${NC}\n" "$xdg_bin_home" >&2
        exit 1
    fi

    install -m 755 "$_out_name" "$xdg_bin_home/$bin_name"

    configure_install_aliases

    printf "${GREEN}%s installed successfully.${NC}\n" "$APPLICATION_NAME"
}

# Function: uninstall
#
# Uninstall GitMini from $XDG_BIN_HOME and unset global aliases for the exposed commands.

configure_uninstall() {
    _out_name="$1"

    installed_out="$xdg_bin_home/$bin_name"
    if [ -e "$installed_out" ]; then
        rm -rf "$installed_out"
    fi

    commands="publish unpublish start refresh current pause combine update list rename delete"

    for cmd in $commands; do
        git config --global --unset "alias.$cmd"
        #  git config --global --unset "alias.$cmd"
    done

    printf "${GREEN}%s uninstalled successfully.${NC}\n" "$APPLICATION_NAME"
}

if [ "$#" -lt 1 ]; then
    printf "${RED}error: too few parameters: %s, insert action${NC}\n" "$#" >&2
    exit 1
fi
action="$1"
shift 1

case "$action" in
    install-aliases)
        configure_install_aliases
        exit 0
    ;;
esac

if [ "$#" -lt 1 ]; then
    printf "${RED}error: too few parameters: %s, insert out-name${NC}\n" "$#" >&2
    exit 1
fi
out_name="$1"
shift 1

if [ ! -e "$out_name" ]; then
    printf "${RED}error: %s does not exists${NC}\n" "$out_name" >&2
    exit 1
fi

case "$action" in
    install)
        configure_install "$out_name"
    ;;
    uninstall)
        configure_uninstall "$out_name"
    ;;
    *)
        printf "${RED}error: action %s not recognized${NC}\n" "$action" >&2
        exit 1
    ;;
esac
