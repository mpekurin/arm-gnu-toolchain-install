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

# Remove temporary files on exit
clean_up ()
{
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
mkdir -p /tmp/$PACKAGE/usr/local/
tar -xf /tmp/$PACKAGE/$PACKAGE.tar.xz --strip-components 1 -C /tmp/$PACKAGE/usr/local/
rm /tmp/$PACKAGE/usr/local/$VERSION-$HOST_ARCH-$TARGET-manifest.txt
rm /tmp/$PACKAGE/$PACKAGE.tar.xz
printf "Done\n"

# Create a Debian package
printf "Preparing necessary files... "
[[ $HOST_ARCH ==  x86_64 ]] && HOST_ARCH_DEB="amd64"
[[ $HOST_ARCH == aarch64 ]] && HOST_ARCH_DEB="arm64"
SIZE=$(du -s /tmp/$PACKAGE/usr/ | cut -f1)
mkdir /tmp/$PACKAGE/DEBIAN/
echo "Package: $BASENAME-${TARGET//_}"                    >  /tmp/$PACKAGE/DEBIAN/control
echo "Version: $VERSION"                                  >> /tmp/$PACKAGE/DEBIAN/control
echo "Section: devel"                                     >> /tmp/$PACKAGE/DEBIAN/control
echo "Priority: optional"                                 >> /tmp/$PACKAGE/DEBIAN/control
echo "Architecture: $HOST_ARCH_DEB"                       >> /tmp/$PACKAGE/DEBIAN/control
echo "Depends: libncursesw5"                              >> /tmp/$PACKAGE/DEBIAN/control
echo "Installed-Size: $SIZE"                              >> /tmp/$PACKAGE/DEBIAN/control
echo "Maintainer: $USER"                                  >> /tmp/$PACKAGE/DEBIAN/control
echo "Description: Arm GNU Toolchain for $TARGET targets" >> /tmp/$PACKAGE/DEBIAN/control
dpkg-deb -bz0 /tmp/$PACKAGE/ /tmp/$PACKAGE/$PACKAGE.deb > /dev/null
rm -r /tmp/$PACKAGE/usr/
printf "Done\n"

tput cnorm

# Install
printf "Installing...\n"
sudo apt -y install /tmp/$PACKAGE/$PACKAGE.deb
