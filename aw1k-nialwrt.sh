#!/bin/bash

# Define colors
BLUE='\033[1;34m'
NC='\033[0m'

folder="immortalwrt"
preset_folder="AW1K-NIALWRT"
script_file="$(basename "$0")"

# Check for --clean argument
if [[ "$1" == "--clean" ]]; then
    echo -e "${BLUE}Cleaning up directories and script...${NC}"
    if [ -d "$folder" ]; then
        echo -e "${BLUE}Removing '$folder' directory...${NC}"
        rm -rf "$folder"
    fi
    if [ -d "$preset_folder" ]; then
        echo -e "${BLUE}Removing '$preset_folder' directory...${NC}"
        rm -rf "$preset_folder"
    fi
    if [ -f "$script_file" ]; then
        echo -e "${BLUE}Removing script file '$script_file'...${NC}"
        rm -f "$script_file"
    fi
    exit 0
fi

clear
echo -e "${BLUE}"
echo "AW1K-NIALWRT BUILD"
echo -e "${NC}"

# Install dependencies
echo -e "${BLUE}Installing required dependencies...${NC}"
sudo apt update -y
sudo apt full-upgrade -y
sudo apt install -y ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential \
    bzip2 ccache clang cmake cpio curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib \
    g++-multilib git gnutls-dev gperf haveged help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev \
    libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev libmpfr-dev libncurses-dev libpython3-dev \
    libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm lrzsz mkisofs msmtp nano \
    ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply python3-docutils \
    python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo uglifyjs \
    upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd

# Remove existing ImmortalWrt directory if present
if [ -d "$folder" ]; then
    echo -e "${BLUE}Removing existing '$folder' directory...${NC}"
    rm -rf "$folder"
fi

# Clone ImmortalWrt repository
repo="https://github.com/immortalwrt/immortalwrt.git"
echo -e "${BLUE}Cloning ImmortalWrt repository...${NC}"
git clone $repo $folder

# Clone preset repository
if [ -d "$preset_folder" ]; then
    echo -e "${BLUE}Removing existing '$preset_folder' directory...${NC}"
    rm -rf "$preset_folder"
fi
preset_repo="https://github.com/nialwrt/AW1K-NIALWRT.git"
echo -e "${BLUE}Cloning preset repository...${NC}"
git clone $preset_repo

# Enter ImmortalWrt directory
cd $folder

# Install feeds
echo -e "${BLUE}Setting up feeds...${NC}"
./scripts/feeds update -a
./scripts/feeds install -a

# Pause for additional custom feeds
echo -e "${BLUE}If you have any additional feeds, add them now.${NC}"
read -p "Press [Enter] to continue..."

# Update feeds again
echo -e "${BLUE}Updating all feeds...${NC}"
./scripts/feeds update -a
./scripts/feeds install -a

# List available branches and tags
echo -e "${BLUE}Available branches:${NC}"
git branch -a

echo -e "${BLUE}Available tags:${NC}"
git tag | sort -V

# Prompt user for target branch or tag
echo -ne "${BLUE}Enter target branch or tag to checkout: ${NC}"
read TARGET_TAG
git checkout $TARGET_TAG

# Copy preset files and config
echo -e "${BLUE}Copying preset files and configuration...${NC}"
cp -r ../$preset_folder/files ./
cp ../$preset_folder/config-upload .config

# Run defconfig
echo -e "${BLUE}Applying defconfig...${NC}"
make defconfig

# Ask if user wants to open menuconfig
echo -ne "${BLUE}Do you want to open 'make menuconfig' to add or adjust packages? (y/n): ${NC}"
read answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    echo -e "${BLUE}Launching menuconfig...${NC}"
    make menuconfig
else
    echo -e "${BLUE}Skipping menuconfig step...${NC}"
fi

# Start the build
echo -e "${BLUE}Starting the build process...${NC}"
start_time=$(date +%s)
make -j$(nproc)
end_time=$(date +%s)

# Calculate build duration
duration=$((end_time - start_time))
hours=$((duration / 3600))
minutes=$(((duration % 3600) / 60))

echo -e "${BLUE}"
echo "Build completed in: ${hours} hour(s) ${minutes} minute(s)"
echo -e "${NC}"

# Go back to parent directory
cd ..

# Cleanup preset folder
if [ -d "$preset_folder" ]; then
    echo -e "${BLUE}Removing preset folder '$preset_folder'...${NC}"
    rm -rf "$preset_folder"
fi

# Cleanup this script file
if [ -f "$script_file" ]; then
    echo -e "${BLUE}Removing script file '$script_file'...${NC}"
    rm -f "$script_file"
fi
