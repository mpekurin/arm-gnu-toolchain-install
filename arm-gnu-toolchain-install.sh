#!/bin/bash

# Arm GNU Toolchain Installer
# Copyright (c) 2022 Maxim Pekurin
# SPDX-License-Identifier: MIT
# URL: https://github.com/mpekurin/arm-gnu-toolchain-install

# Init
PACKAGE="arm-gnu-toolchain"
HOST_PLATFORM=$(uname -m)
if [[ $HOST_PLATFORM != "x86_64" && $HOST_PLATFORM != "aarch64" ]]
then
  printf "Arm GNU Toolchain is not available for %s platform.\n" $HOST_PLATFORM
  exit 1
fi

# Fetch
printf "Fetching... "
if [[ $HOST_PLATFORM == "x86_64" ]]
then
  FILES=($(curl -s https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads \
        | grep -Po "(?<=binrel/)${PACKAGE}.*${HOST_PLATFORM}.*(?=.tar.xz\?)" \
        | grep -v "darwin"))
  HOST_PLATFORM_DEB="amd64"
else
  FILES=($(curl -s https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads \
        | grep -Po "(?<=binrel/)${PACKAGE}.*${HOST_PLATFORM}.*(?=.tar.xz\?)" \
        | grep -v "x86_64"))
  HOST_PLATFORM_DEB="arm64"
fi
printf "Done\n"

# Select a version
for i in $(seq 0 $((${#FILES[*]} - 1)))
do
  printf "[%2i] %s\n" $i ${FILES[i]}
done
while [[ $FILE_INDEX != +([0-9]) || $FILE_INDEX -ge ${#FILES[*]} ]]
do
  read -p "Please select a version to install: " FILE_INDEX
done
TAR_ROOT=${FILES[FILE_INDEX]}
TAR_NAME="${TAR_ROOT}.tar.xz"
VERSION=$(grep -oP "(?<=${PACKAGE}-).*?(?=-${HOST_PLATFORM})" <<< $TAR_ROOT)
TARGET_PLATFORM=$(grep -oP "(?<=${HOST_PLATFORM}-).*" <<< $TAR_ROOT | tr -d _)
PKG_ROOT="${PACKAGE}-${TARGET_PLATFORM}_${VERSION}_${HOST_PLATFORM_DEB}"
PKG_NAME="${PACKAGE}-${TARGET_PLATFORM}_${VERSION}_${HOST_PLATFORM_DEB}.deb"
TMP_DIR="/tmp/${PKG_ROOT}"

# Configure a trap to remove temporary files on exit
function clean_up {
  rm -rf $TMP_DIR
  rm -f /tmp/$PKG_NAME
}
trap clean_up EXIT

# Download
printf "Downloading %s...\n" $TAR_ROOT
URL="https://developer.arm.com/-/media/files/downloads/gnu/${VERSION}/binrel/${TAR_NAME}"
mkdir $TMP_DIR
curl -L#o $TMP_DIR/$TAR_NAME $URL

# Extract
printf "Extracting... "
tar -xf $TMP_DIR/$TAR_NAME -C $TMP_DIR
rm $TMP_DIR/$TAR_NAME
printf "Done\n"

# Create a Debian package
mv $TMP_DIR/$TAR_ROOT $TMP_DIR/usr
mkdir $TMP_DIR/DEBIAN
echo "Package: ${PACKAGE}-${TARGET_PLATFORM}"                        >  $TMP_DIR/DEBIAN/control
echo "Version: ${VERSION}"                                           >> $TMP_DIR/DEBIAN/control
echo "Section: devel"                                                >> $TMP_DIR/DEBIAN/control
echo "Priority: optional"                                            >> $TMP_DIR/DEBIAN/control
echo "Architecture: ${HOST_PLATFORM_DEB}"                            >> $TMP_DIR/DEBIAN/control
echo "Depends: libncursesw5"                                         >> $TMP_DIR/DEBIAN/control
if [[ $TARGET_PLATFORM == "arm-none-eabi" ]]
then
  echo "Conflicts: gcc-arm-none-eabi, binutils-arm-none-eabi"        >> $TMP_DIR/DEBIAN/control
fi
echo "Installed-Size: $(du -s ${TMP_DIR}/usr | cut -f1)"             >> $TMP_DIR/DEBIAN/control
echo "Maintainer: ${USER}"                                           >> $TMP_DIR/DEBIAN/control
echo "Description: Arm GNU Toolchain for ${TARGET_PLATFORM} targets" >> $TMP_DIR/DEBIAN/control
dpkg-deb --root-owner-group --build $TMP_DIR /tmp/$PKG_NAME
rm -r $TMP_DIR

# Install
echo "Installing..."
sudo apt install /tmp/$PKG_NAME
rm /tmp/$PKG_NAME
