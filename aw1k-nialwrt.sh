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
    echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Updating package lists (feeds)...${NC}"
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -ne "${BLUE}Press Enter after editing custom feeds... ${NC}";
    read
    ./scripts/feeds update -a && ./scripts/feeds install -a || return 1
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} ${GREEN}${BOLD}Package lists updated.${NC}"
}

select_target() {
    echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Selecting target branch/tag...${NC}"
    echo -e "${YELLOW}Branches:${NC}";
    git branch -a
    echo -e "${YELLOW}Tags:${NC}";
    git tag | sort -V
    while true;
    do
        prompt "${BLUE}Enter branch/tag to checkout: ${NC}" target_tag
        git checkout "$target_tag" && {
            echo -e "${GREEN}${BOLD}SUCCESS:${NC} ${GREEN}${BOLD}Checked out to: $target_tag${NC}"
            break;
        }
        echo -e "${RED}${BOLD}ERROR:${NC} ${RED}${BOLD}Invalid branch/tag.${NC}"
    done
}

ensure_preset() {
    if [[ ! -d "$preset_folder" ]]; then
        echo -e "${YELLOW}${BOLD}NOTICE:${NC} Preset folder '$preset_folder' is missing. Re-downloading..."
        git clone "$preset_repo" "$preset_folder" || {
            echo -e "${RED}${BOLD}ERROR:${NC} Failed to clone preset from $preset_repo"
            exit 1
        }
        echo -e "${GREEN}${BOLD}SUCCESS:${NC} Preset successfully re-downloaded."
    fi
}

run_menuconfig() {
    echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Running menuconfig...${NC}"
    make menuconfig && echo -e "${GREEN}${BOLD}SUCCESS:${NC} ${GREEN}${BOLD}Configuration saved.${NC}" || echo -e "${RED}${BOLD}ERROR:${NC} ${RED}${BOLD}Configuration failed.${NC}"
}

show_output_location() {
    echo -e "${GREEN}${BOLD}SUCCESS:${NC} ${GREEN}${BOLD}Firmware output: ${YELLOW}$(pwd)/bin/targets/${NC}"
}

start_build() {
    echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Building firmware...${NC}"
    local MAKE_J=$(nproc)
    echo -e "${CYAN}Using make -j${MAKE_J}${NC}"

    while true;
    do
        local start_time=$(date +%s)
        make -j"${MAKE_J}" && {
            local duration=$(( $(date +%s) - start_time ))
            local hours=$((duration / 3600))
            local minutes=$(((duration % 3600) / 60))
            local seconds=$((duration % 60))

            echo -e "${GREEN}${BOLD}SUCCESS:${NC} ${GREEN}${BOLD}Build finished in ${hours}h ${minutes}m ${seconds}s.${NC}"
            show_output_location
            break
        }

        echo -e "${RED}${BOLD}ERROR:${NC} ${RED}${BOLD}Build failed. Debugging with verbose output...${NC}"
        make -j1 V=s
        echo -ne "${RED}Fix errors, then press Enter to retry... ${NC}"
        read

        make distclean
        update_feeds || return 1
        select_target
        run_menuconfig

        local retry_start=$(date +%s)
        make -j"${MAKE_J}" && {
            local retry_duration=$(( $(date +%s) - retry_start ))
            local rh=$((retry_duration / 3600))
            local rm=$(((retry_duration % 3600) / 60))

            local rs=$((retry_duration % 60))

            echo -e "${GREEN}${BOLD}SUCCESS:${NC} ${GREEN}${BOLD}Rebuild (after fallback) finished in ${rh}h ${rm}m ${rs}s.${NC}"
            show_output_location
        } || echo -e "${RED}${BOLD}ERROR:${NC} ${RED}${BOLD}Build still failed after fallback.${NC}"
        break
    done
}

build_menu() {
    echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Starting first-time build...${NC}"
    git clone "$repo" "$distro" || {
        echo -e "${RED}${BOLD}ERROR:${NC} ${RED}${BOLD}Git clone failed.${NC}"
        exit 1;
    }
    git clone "$preset_repo" "$preset_folder" || {
        echo -e "${RED}${BOLD}ERROR:${NC} ${RED}${BOLD}Git clone preset failed.${NC}"
        exit 1;
    }
    pushd "$distro" > /dev/null || exit 1
    update_feeds || exit 1
    select_target
    cp -r "../$preset_folder/files" ./
    cp "../$preset_folder/config-upload" .config
    make defconfig
    run_menuconfig
    start_build
    popd > /dev/null
}

rebuild_menu() {
    pushd "$distro" > /dev/null || exit 1
    echo -e "${BLUE}${BOLD}Rebuild Options:${NC}"
    echo -e "1) Fresh Rebuild (clean and reconfigure)"
    echo -e "2) Configure and Rebuild (new .config)"
    echo -e "3) Existing Rebuild (use current config)"

    while true;
    do
        prompt "${YELLOW}Select option [1/2/3]: ${NC}" opt
        case "$opt" in
            1)
                echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Performing fresh rebuild...${NC}"
                make distclean
                update_feeds || return 1
                select_target
                echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Copying preset files and configuration...${NC}"
                cp -r "../$preset_folder/files" ./
                cp "../$preset_folder/config-upload" .config
                make defconfig
                run_menuconfig
                start_build
                break
                ;;
            2)
                echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Configuring and rebuilding (new .config)...${NC}"
                echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}deleting preset files and configuration...${NC}"
                rm -rf "./files"
                rm -f ".config"
                echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}restore preset files and configuration...${NC}"

                cp -r "../$preset_folder/files" ./
                cp "../$preset_folder/config-upload" .config
                make defconfig
                run_menuconfig
                start_build

                break
                ;;
            3)
                echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Rebuilding with existing settings...${NC}"
                start_build
                break
                ;;
            *)
                echo -e "${RED}${BOLD}ERROR:${NC} ${RED}${BOLD}Invalid selection.${NC}"
                ;;
        esac
    done

    popd > /dev/null
}

cleanup() {
    rm -rf "$preset_folder"
    rm -f "$script_file"    
}

# Check for --clean argument
if [[ "$1" == "--clean" ]]; then
    cleanup
    exit 0
fi

check_git
main_menu

# Install dependencies
echo -e "${CYAN}${BOLD}STEP:${NC} ${CYAN}${BOLD}Installing dependencies required for ImmortalWrt...${NC}"
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential
    bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib
    g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev
    libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev
    libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano
    ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils
    python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs
    upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd

if [ -d "$distro" ]; then
    echo -e "${BLUE}${BOLD}Directory '$distro' exists.${NC}"
    rebuild_menu
else
    build_menu
fi

cleanup
