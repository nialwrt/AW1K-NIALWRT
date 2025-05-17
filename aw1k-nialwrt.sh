#!/bin/bash

script_file="$(basename "$0")"

# Color codes
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Distro and preset configuration
distro="immortalwrt"
repo="https://github.com/immortalwrt/immortalwrt.git"
preset_folder="AW1K-NIALWRT"
preset_repo="https://github.com/nialwrt/AW1K-NIALWRT.git"
deps=(ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential
    bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib
    g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev
    libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev
    libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano
    ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils
    python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs
    upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd)
choice=""
target_tag=""
opt=""

prompt() {
    echo -ne "$1"
    read -r REPLY
    eval "$2=\"\$REPLY\""
}

check_git() {
    command -v git &>/dev/null || {
        echo -e "${RED}${BOLD}ERROR:${NC} ${RED}${BOLD}Git is required.${NC}"
        exit 1
    }
}

main_menu() {
    clear
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
    echo -e "${MAGENTA}${BOLD}  AW1K-NIALWRT Firmware Build  ${NC}"
    echo -e "${MAGENTA}  github.com/nialwrt          ${NC}"
    echo -e "${MAGENTA}  Telegram: @NIALVPN                  ${NC}"
    echo -e "${MAGENTA}${BOLD}--------------------------------------${NC}"
}

update_feeds() {
    echo -e "${CYAN}${BOLD}STEP:${NC} Updating package lists (feeds)..."
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BLUE}Press Enter after editing feeds (if needed)... ${NC}"
    read
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} Feeds updated."
}

select_target() {
    echo -e "${CYAN}${BOLD}STEP:${NC} Selecting target branch/tag..."
    echo -e "${YELLOW}Branches:${NC}"
    git branch -a
    echo -e "${YELLOW}Tags:${NC}"
    git tag | sort -V
    while true; do
        prompt "${BLUE}Enter branch/tag to checkout: ${NC}" target_tag
        git checkout "$target_tag" && {
            echo -e "${GREEN}${BOLD}Checked out to: $target_tag${NC}"
            break
        }
        echo -e "${RED}${BOLD}Invalid branch/tag.${NC}"
    done
}

ensure_preset() {
    echo -e "${YELLOW}Cleaning existing preset and config..."
    rm -rf ./files .config

    if [[ -d "$preset_folder" ]]; then
        echo -e "${YELLOW}Removing old preset folder...${NC}"
        rm -rf "$preset_folder"
    fi

    echo -e "${CYAN}Cloning preset from $preset_repo..."
    git clone "$preset_repo" "$preset_folder" || {
        echo -e "${RED}${BOLD}ERROR:${NC} Failed to clone preset."
        exit 1
    }

    echo -e "${GREEN}Preset cloned successfully.${NC}"
}

apply_preset() {
    echo -e "${CYAN}Copying preset files and config..."
    cp -r "$preset_folder/files" ./
    cp "$preset_folder/config-upload" .config
}

run_menuconfig() {
    echo -e "${CYAN}Running menuconfig..."
    make menuconfig && echo -e "${GREEN}Saved configuration.${NC}" || echo -e "${RED}menuconfig failed.${NC}"
}

show_output_location() {
    echo -e "${GREEN}Firmware output: ${YELLOW}$(pwd)/bin/targets/${NC}"
}

start_build() {
    echo -e "${CYAN}Building firmware..."
    local MAKE_J=$(nproc)
    echo -e "Using make -j${MAKE_J}"

    while true; do
        local start_time=$(date +%s)
        make -j"$MAKE_J" && {
            local duration=$(( $(date +%s) - start_time ))
            printf "${GREEN}Build finished in %02dh %02dm %02ds${NC}\n" $((duration/3600)) $(((duration%3600)/60)) $((duration%60))
            show_output_location
            break
        }

        echo -e "${RED}Build failed. Retrying with verbose output...${NC}"
        make -j1 V=s
        echo -ne "${YELLOW}Fix the error. Press Enter to retry with clean build...${NC}"
        read

        make distclean
        update_feeds || return 1
        select_target
        run_menuconfig

        local retry_start=$(date +%s)
        make -j"$MAKE_J" && {
            local retry_duration=$(( $(date +%s) - retry_start ))
            printf "${GREEN}Rebuild finished in %02dh %02dm %02ds${NC}\n" $((retry_duration/3600)) $(((retry_duration%3600)/60)) $((retry_duration%60))
            show_output_location
        } || echo -e "${RED}Build still failed after retry.${NC}"
        break
    done
}

cleanup() {
    echo -e "${YELLOW}${BOLD}Cleaning up build script and preset files...${NC}"
    rm -f "$script_file"
    rm -rf "$preset_folder"
}

build_menu() {
    echo -e "${CYAN}Cloning repo: $repo..."
    git clone --depth=1 "$repo" "$distro" || {
        echo -e "${RED}Git clone failed.${NC}"
        exit 1
    }

    cd "$distro" || exit 1
    update_feeds || exit 1
    select_target
    ensure_preset
    apply_preset
    make defconfig
    run_menuconfig
    start_build
    cleanup
}

rebuild_menu() {
    cd "$distro" || exit 1
    echo -e "${BLUE}Rebuild Options:${NC}"
    echo "1) Fresh Rebuild (clean)"
    echo "2) Rebuild with New Config"
    echo "3) Continue with Existing Config"

    while true; do
        prompt "${YELLOW}Choose option [1/2/3]: ${NC}" opt
        case "$opt" in
            1)
                make distclean
                update_feeds || return 1
                select_target
                ensure_preset
                apply_preset
                make defconfig
                run_menuconfig
                start_build
                cleanup
                break
                ;;
            2)
                select_target
                ensure_preset
                apply_preset
                make defconfig
                run_menuconfig
                start_build
                cleanup
                break
                ;;
            3)
                start_build
                cleanup
                break
                ;;
            *)
                echo -e "${RED}Invalid choice.${NC}" ;;
        esac
    done
}

check_git
main_menu

echo -e "${CYAN}Installing build dependencies...${NC}"
sudo apt update -y && sudo apt full-upgrade -y
sudo apt install -y "${deps[@]}"

if [ -d "$distro/.git" ]; then
    echo -e "${BLUE}Directory '$distro' already exists.${NC}"
    rebuild_menu
else
    build_menu
fi
