#!/bin/bash

# Arm GNU Toolchain Installer
# Copyright (c) 2022 Maxim Pekurin
# SPDX-License-Identifier: MIT
# URL: https://github.com/mpekurin/arm-gnu-toolchain-install

# Init
BASENAME="arm-gnu-toolchain"
HOST_ARCH=$(uname -m)
VERSION_PATTERN="\d+\.\d+\.\D+\d+"
TARGET_PATTERN=".*"
if [[ $HOST_ARCH != @(x86_64|aarch64) ]]
then
  printf "Arm GNU Toolchain is not available for $HOST_ARCH architecture.\n"
  exit 1
fi

# Fetch
printf "Fetching... "
URL="https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads"
PATTERN="(?<=binrel\/)$BASENAME-$VERSION_PATTERN-$HOST_ARCH-$TARGET_PATTERN(?=\.tar\.xz\?)"
PACKAGES=($(curl -s $URL | grep -Po $PATTERN))
printf "Done\n"

# Select a package
for i in ${!PACKAGES[@]}
do
  printf "[%2i] %s\n" $i ${PACKAGES[i]}
done
unset INDEX
while [[ $INDEX != +([0-9]) || $INDEX -ge ${#PACKAGES[@]} ]]
do
  read -p "Please select a package to install: " INDEX
done
PACKAGE=${PACKAGES[INDEX]}
VERSION=$(grep -Po "(?<=$BASENAME-)$VERSION_PATTERN(?=-$HOST_ARCH)" <<< $PACKAGE)
TARGET=$(grep -Po "(?<=$VERSION-$HOST_ARCH-)$TARGET_PATTERN" <<< $PACKAGE)

# Remove temporary files on exit
function clean_up {
  rm -r /tmp/$PACKAGE/
  tput cnorm
}
trap clean_up EXIT

tput civis

# Download
printf "Downloading $PACKAGE...\n"
URL="https://developer.arm.com/-/media/files/downloads/gnu/$VERSION/binrel/$PACKAGE.tar.xz"
mkdir /tmp/$PACKAGE/
curl -L#o /tmp/$PACKAGE/$PACKAGE.tar.xz $URL

# Extract
printf "Extracting... "
mkdir /tmp/$PACKAGE/usr/
tar -xf /tmp/$PACKAGE/$PACKAGE.tar.xz --strip-components 1 -C /tmp/$PACKAGE/usr/
rm /tmp/$PACKAGE/usr/$VERSION-$HOST_ARCH-$TARGET-manifest.txt
rm /tmp/$PACKAGE/$PACKAGE.tar.xz
printf "Done\n"

# Create a Debian package
printf "Preparing necessary files... "
[[ $HOST_ARCH ==  x86_64 ]] && HOST_ARCH_DEB="amd64"
[[ $HOST_ARCH == aarch64 ]] && HOST_ARCH_DEB="arm64"
SIZE=$(du -s /tmp/$PACKAGE/usr/ | cut -f1)
mkdir /tmp/$PACKAGE/DEBIAN/
echo "Package: $BASENAME-${TARGET//_}"                        >  /tmp/$PACKAGE/DEBIAN/control
echo "Version: $VERSION"                                      >> /tmp/$PACKAGE/DEBIAN/control
echo "Section: devel"                                         >> /tmp/$PACKAGE/DEBIAN/control
echo "Priority: optional"                                     >> /tmp/$PACKAGE/DEBIAN/control
echo "Architecture: $HOST_ARCH_DEB"                           >> /tmp/$PACKAGE/DEBIAN/control
echo "Depends: libncursesw5"                                  >> /tmp/$PACKAGE/DEBIAN/control
if [[ $TARGET == "arm-none-eabi" ]]
then
  echo "Conflicts: gcc-arm-none-eabi, binutils-arm-none-eabi" >> /tmp/$PACKAGE/DEBIAN/control
fi
echo "Installed-Size: $SIZE"                                  >> /tmp/$PACKAGE/DEBIAN/control
echo "Maintainer: $USER"                                      >> /tmp/$PACKAGE/DEBIAN/control
echo "Description: Arm GNU Toolchain for $TARGET targets"     >> /tmp/$PACKAGE/DEBIAN/control
dpkg-deb -bz0 /tmp/$PACKAGE/ /tmp/$PACKAGE/$PACKAGE.deb > /dev/null
rm -r /tmp/$PACKAGE/usr/
printf "Done\n"

tput cnorm

# Install
printf "Installing...\n"
sudo apt install /tmp/$PACKAGE/$PACKAGE.deb
