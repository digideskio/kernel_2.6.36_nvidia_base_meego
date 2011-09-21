#!/bin/bash -e

if [ "$1" = "" ] ; then
    KERNEL_DEST=/media/sf_C_DRIVE/MeeGo
else
    KERNEL_DEST=$2
fi

if [ "$2" = "" ] ; then
    CONFIG=config-meego
else
    CONFIG=$2
fi

if [ "$3" = "" ] ; then
    ROOTFS_DEST=$PWD/meego-root-fs-vgrade-mods
#    ROOTFS_DEST=/media/meego-sd
else
    ROOTFS_DEST=$3
fi

if [ "$4" = "" ] ; then
    CC=arm-linux-gnueabi-
else
    CC=$4
fi

ARCH=$(uname -m)
CORES=1
if test "-$ARCH-" = "-x86_64-" || test "-$ARCH-" = "-i686-"
then
    CORES=$(cat /proc/cpuinfo | grep processor | wc -l)
    let CORES=$CORES+1
fi

echo ""; echo "Building kernel"; echo ""
make clean
if [ -d $ROOTFS_DEST/lib/modules ] ; then
    sudo chmod -R 777 $ROOTFS_DEST/lib/modules
    sudo rm -rf $ROOTFS_DEST/lib/modules
fi

rm arch/arm/boot/compressed/lib1funcs.S || echo ""
cp configs/$CONFIG .config
rm -rf deploy
mkdir deploy
rm arch/arm/boot/zImage || echo ""
make -j${CORES} ARCH=arm LOCALVERSION= CROSS_COMPILE="${CCACHE} ${CC}" CONFIG_DEBUG_SECTION_MISMATCH=y zImage
make -j${CORES} ARCH=arm LOCALVERSION= CROSS_COMPILE="${CCACHE} ${CC}" CONFIG_DEBUG_SECTION_MISMATCH=y modules
cp arch/arm/boot/zImage deploy/zImage
make ARCH=arm CROSS_COMPILE=${CC} modules_install INSTALL_MOD_PATH=deploy/
sudo make ARCH=arm CROSS_COMPILE=${CC} modules_install INSTALL_MOD_PATH=$ROOTFS_DEST/

# Although not used, copy it to the rootfs boot folder anyway.
sudo cp deploy/zImage $ROOTFS_DEST/boot
sudo cp deploy/zImage $KERNEL_DEST

echo ""; echo "Building atheros ar6000 module"; echo ""
pushd atheros/ar6k_sdk
./build.sh
sudo cp host/os/linux/ar6000.ko $ROOTFS_DEST/
sudo cp host/os/linux/ar6000.ko ../../deploy/
popd

sync
sync

echo ""; echo "All done!"; echo ""

exit 0
