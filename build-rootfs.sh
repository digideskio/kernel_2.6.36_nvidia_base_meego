#!/bin/bash -e

# This script

# reformat
# recopy
# remodify

REMOUNT=0
REFORMAT=0
RECOPY=0
REMODIFY=0

function unMountIfMounted
{
echo $1
    while sudo grep $1 /etc/mtab &>/dev/null
    do
        OLDMOUNT=`sudo grep -m1 $1 /etc/mtab | awk '{print $2}'`
        echo $OLDMOUNT
        echo umount $OLDMOUNT
        sudo umount $OLDMOUNT
    done
}

function exitShowingUsage
{
    echo "Hard coded script for patching vgrade's rootfs image"
    echo "Not useful for anything else. Assumes you've got a"
    echo "sd card and mg-tablet-tegra.sfdisk from vgrade's fs"
    echo "and patches it with some parts (including tests"
    echo "Very hacky, you may need to run it a few times before"
    echo "it unmounts things properly!"
    echo ""
    echo "Usage build-rootfs.sh {reformat|recopy|remodify|remount} device"
    echo " e.g. build-rootfs.sh reformat sdb"
    echo "     : reformat - reformats sd card, recopies mg-tablet-tegra.img, patches with meego-root-fs-vgrade-mods (very slow)"
    echo "     : recopy   - recopies mg-tablet-tegra.img, patches with meego-root-fs-vgrade-mods (very slow)"
    echo "     : remodify - patches with meego-root-fs-vgrade-mods (fast)"
    echo "     : remount  - just mounts /media/meego-sd (fast)"
    echo "     : umount   - umounts /media/meego-sd (fast)"
    exit 1
}

if [ "$1" = "reformat" ] ;
then
    REMOUNT=1
    REFORMAT=1
    RECOPY=1
    REMODIFY=1
    UMOUNT=1
else
    if [ "$1" = "recopy" ] ;
    then
        REMOUNT=1
        REFORMAT=0
        RECOPY=1
        REMODIFY=1
        UMOUNT=1
    else
        if [ "$1" = "remodify" ] ;
        then
            REMOUNT=1
            REFORMAT=0
            RECOPY=0
            REMODIFY=1
            UMOUNT=1
        else
            if [ "$1" = "remount" ] ;
            then
                REMOUNT=1
                REFORMAT=0
                RECOPY=0
                REMODIFY=0
                UMOUNT=1
            else
                if [ "$1" = "umount" ] ;
                then
                    REMOUNT=0
                    REFORMAT=0
                    RECOPY=0
                    REMODIFY=0
                    UMOUNT=1
                else
                    exitShowingUsage
                fi
            fi
        fi
    fi
fi

if [ "$REFORMAT" = "0" -a "$RECOPY" = "0" -a "$REMODIFY" = "0" -a "$REMOUNT" = "0" -a "$UMOUNT" = "0" ] ; then
    exitShowingUsage
fi

if [ "$2" == "" ] ; then
echo "Error: Device not specified!"
    exitShowingUsage
fi

DEVICE=$2

if [ -z /dev/$DEVICE ] ; then
    echo "Error: /dev/$DEVICE not found!"
    exitShowingUsage
fi

if [ "$UMOUNT" = "1" ] ; then
    sync; sync; sync
    unMountIfMounted /dev/${DEVICE}1
    unMountIfMounted /dev/${DEVICE}2
    unMountIfMounted /dev/mapper/loop0p2
fi

if [ "$REMOUNT" = "1" ] ; then
    if [ "$REFORMAT" = "1" ] ; then
        if [ ! -f mg-tablet-tegra.sfdisk ] ; then
            echo "Error: Couldn't open mg-tablet-tegra.sfdisk!"
            exitShowingUsage
        fi
        sudo sfdisk -d /dev/${DEVICE} < mg-tablet-tegra.sfdisk
        sudo mkfs -t ext3 /dev/${DEVICE}2
        sudo tune2fs -i 0 /dev/${DEVICE}2
        sudo tune2fs -c 0 /dev/${DEVICE}2
    fi

    if [ ! -d /media/meego-sd ] ; then
       sudo mkdir /media/meego-sd
    fi

    sudo mount -t ext3 /dev/${DEVICE}2 /media/meego-sd -O "rw,nosuid,nodev,uhelper=udisks"

    if [ "$?" != "0" ] ; then
        echo "Error: Couldn't mount /dev/${DEVICE}2 at /media/meego-sd!"
        exitShowingUsage
    fi
    if [ ! -f ../mg-tablet-tegra.img ] ; then
        echo "Error: Couldn't open ../mg-tablet-tegra.img"
        exitShowingUsage
    fi
    if [ "$REFORMAT" = "0" -a "$RECOPY" = "1" ] ; then
        sudo rm -rf /media/meego-sd/*
    fi
    sudo kpartx -v -a ../mg-tablet-tegra.img
    sudo mount /dev/mapper/loop0p2 /media/meego/
fi

if [ "$RECOPY" = "1" ] ; then
    sudo rsync -axS --exclude=/tmp/* --progress /media/meego/* /media/meego-sd
fi

if [ "$REMODIFY" = "1" ] ; then
    sudo rsync -axS --progress meego-root-fs-vgrade-mods/* /media/meego-sd
fi

# sudo rm -rf /media/meego-sd/tmp/* || echo "/tmp already clean"
# sudo rm -rf /media/meego-sd/var/log/* || echo "/var/log already clean"

echo ""; echo "All done!"; echo ""

exit 0
