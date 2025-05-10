#!/bin/bash

# Warna biru
BLUE='\033[1;34m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "----------------------"
echo "    AW1K-NIALWRT"
echo "----------------------"
echo -e "${NC}"

# Install dependencies
echo -e "${BLUE}MENGINSTALL DEPENDENCIES${NC}"
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

# Buang folder ImmortalWrt jika ada
folder="immortalwrt"
if [ -d "$folder" ]; then
    echo -e "${BLUE}MENGHAPUS FOLDER $folder YANG SUDAH ADA${NC}"
    rm -rf "$folder"
fi

# Clone repo ImmortalWrt
repo="https://github.com/immortalwrt/immortalwrt.git"
git clone $repo $folder

# Clone preset repo
preset_repo="https://github.com/nialwrt/AW1K-NIALWRT.git"
preset_folder="AW1K-NIALWRT"
if [ -d "$preset_folder" ]; then
    echo -e "${BLUE}MENGHAPUS FOLDER $preset_folder YANG SUDAH ADA${NC}"
    rm -rf "$preset_folder"
fi
git clone $preset_repo

# Masuk ke folder ImmortalWrt
cd $folder

# Install feeds
echo -e "${BLUE}MENGINSTALL FEEDS${NC}"
./scripts/feeds update -a
./scripts/feeds install -a

# Pause untuk masukkan feeds custom
echo -e "${BLUE}MASUKKAN JIKA ADA FEEDS LAIN${NC}"
read -p "Tekan [Enter] untuk teruskan"

# Update feeds
echo -e "${BLUE}MENGUPDATE FEEDS${NC}"
./scripts/feeds update -a
./scripts/feeds install -a

# List branch dan tag
echo -e "${BLUE}LIST BRANCH${NC}"
git branch -a

echo -e "${BLUE}LIST TAG${NC}"
git tag | sort -V

# Pilih branch/tag
echo -ne "${BLUE}MASUKKAN BRANCH/TAG: ${NC}"
read TARGET_TAG
git checkout $TARGET_TAG

# Salin preset files dan config
echo -e "${BLUE}MENYALIN PRESET FILES DAN CONFIG${NC}"
cp -r ../$preset_folder/files ./
cp ../$preset_folder/config-upload .config

# Jalankan defconfig
echo -e "${BLUE}MENJALANKAN DEFCONFIG${NC}"
make defconfig

# Tanya user apakah mau buka menuconfig
echo -ne "${BLUE}MAHU BUKA MENUCONFIG UNTUK MENAMBAH PACKAGE? (y/n): ${NC}"
read jawaban

if [[ "$jawaban" == "y" || "$jawaban" == "Y" ]]; then
    echo -e "${BLUE}MEMBUKA MENUCONFIG${NC}"
    make menuconfig
else
    echo -e "${BLUE}SKIP MENUCONFIG${NC}"
fi

# Jalankan build
echo -e "${BLUE}MENJALANKAN BUILD${NC}"
start_time=$(date +%s)
make -j$(nproc)
end_time=$(date +%s)

duration=$((end_time - start_time))
hours=$((duration / 3600))
minutes=$(((duration % 3600) / 60))

echo -e "${BLUE}"
echo "----------------------"
echo "SELESAI: ${hours} jam ${minutes} min"
echo "----------------------"
echo -e "${NC}"
