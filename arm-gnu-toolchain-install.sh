#!/bin/bash

# Arm GNU Toolchain Install
# Copyright (c) 2022 Maxim Pekurin
# SPDX-License-Identifier: MIT
# URL: https://github.com/mpekurin/arm-gnu-toolchain-install

help ()
{
  echo "Download and install Arm GNU Toolchain as a Debian package."
  echo
  echo "Usage: bash $(basename $0) [options...]"
  echo "  -h           show this help and exit"
  echo "  -v <pattern> use the pattern to filter the packages by their version"
  echo "  -t <pattern> use the pattern to filter the packages by their target"
  echo "  -l           install the latest version available"
}

# Init
BASENAME="arm-gnu-toolchain"
HOST_ARCH=$(uname -m)
version_pattern="\d+\.\d+\.\D+\d+"
target_pattern=".*"
if [[ $HOST_ARCH != @(x86_64|aarch64) ]]
then
  printf "Arm GNU Toolchain is not available for $HOST_ARCH architecture\n"
  exit 1
fi

# Process options
unset INSTALL_LATEST
while getopts ":hv:t:l" flag
do
  case $flag in
    h) help && exit 0;;
    v) version_pattern=$OPTARG;;
    t) target_pattern=$OPTARG;;
    l) INSTALL_LATEST=1;;
  esac
done

# Create temp dir
TMP_DIR=$(mktemp -d)
chmod +rwx $TMP_DIR

# Clean up on exit
trap 'rm -r $TMP_DIR/ && tput cnorm' EXIT

# Fetch
printf "Fetching... "
URL="https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads"
PATTERN="(?<=binrel\/)$BASENAME-$version_pattern-$HOST_ARCH-$target_pattern(?=\.tar\.xz\?)"
PACKAGES=($(curl -s $URL | grep -Po $PATTERN | grep -v "darwin"))
printf "Done\n"

# Select a package
if [[ ${#PACKAGES[@]} -eq 0 ]]
then
  printf "Cannot find a package that matches the pattern: $BASENAME-$version_pattern-$HOST_ARCH-$target_pattern\n"
  exit 1
elif [[ $INSTALL_LATEST -eq 1 ]]
then
  PACKAGE=${PACKAGES[0]}
else
  for i in ${!PACKAGES[@]}
  do
    printf "[%2i] %s\n" $i ${PACKAGES[i]}
  done
  unset i
  while [[ $i != +([0-9]) || $i -ge ${#PACKAGES[@]} ]]
  do
    read -p "Please select a package to install: " i
  done
  PACKAGE=${PACKAGES[i]}
fi
VERSION=$(grep -Po "(?<=$BASENAME-)$version_pattern(?=-$HOST_ARCH)" <<< $PACKAGE)
TARGET=$(grep -Po "(?<=$VERSION-$HOST_ARCH-)$target_pattern" <<< $PACKAGE)

tput civis

# Download
printf "Downloading $PACKAGE...\n"
URL="https://developer.arm.com/-/media/files/downloads/gnu/$VERSION/binrel/$PACKAGE.tar.xz"
curl -L#o $TMP_DIR/$PACKAGE.tar.xz $URL

# Extract
printf "Extracting... "
# The toolchain will be installed to /usr/local/ to avoid conflicts with gdb and some other packages.
# This is probably not good but whatever.
mkdir -p $TMP_DIR/usr/local/
tar -xf $TMP_DIR/$PACKAGE.tar.xz --strip-components 1 -C $TMP_DIR/usr/local/
rm $TMP_DIR/usr/local/*.txt
rm $TMP_DIR/$PACKAGE.tar.xz
printf "Done\n"

# Create a Debian package
printf "Preparing necessary files... "
[[ $HOST_ARCH ==  x86_64 ]] && HOST_ARCH_DEB="amd64"
[[ $HOST_ARCH == aarch64 ]] && HOST_ARCH_DEB="arm64"
SIZE=$(du -s $TMP_DIR | cut -f1)
mkdir $TMP_DIR/DEBIAN/
echo "Package: $BASENAME-${TARGET//_}"                    >  $TMP_DIR/DEBIAN/control
echo "Version: $VERSION"                                  >> $TMP_DIR/DEBIAN/control
echo "Section: devel"                                     >> $TMP_DIR/DEBIAN/control
echo "Priority: optional"                                 >> $TMP_DIR/DEBIAN/control
echo "Architecture: $HOST_ARCH_DEB"                       >> $TMP_DIR/DEBIAN/control
echo "Installed-Size: $SIZE"                              >> $TMP_DIR/DEBIAN/control
echo "Maintainer: $USER"                                  >> $TMP_DIR/DEBIAN/control
echo "Description: Arm GNU Toolchain for $TARGET targets" >> $TMP_DIR/DEBIAN/control
dpkg-deb -bz0 $TMP_DIR/ $TMP_DIR/$PACKAGE.deb > /dev/null
rm -r $TMP_DIR/usr/
printf "Done\n"

tput cnorm

# Install
printf "Installing...\n"
sudo apt -y --allow-downgrades install $TMP_DIR/$PACKAGE.deb
