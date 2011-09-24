#!/bin/bash -e

# This script

# reformat
# recopy
# remodify

REMOUNT=0
REFORMAT=0
RECOPY=0
REMODIFY=0
COPY_VAR_LOG=1

function unMountIfMounted
{
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
    echo "sd card and mg-tablet-tegra.img (vgrade's root fs)"
    echo "and patches it with some parts (including tests"
    echo "Very hacky, you may need to run it a few times before"
    echo "it unmounts things properly!"
    echo ""
    echo "Usage build-rootfs.sh {reformat|recopy|remodify|remount} device <image-stub-name>"
    echo " e.g. build-rootfs.sh reformat sdb ../mg-tablet-tegra"
    echo "     : reformat - reformats sd card, recopies mg-tablet-tegra.img, patches with meego-root-fs-vgrade-mods (very slow)"
    echo "     : recopy   - recopies mg-tablet-tegra.img, patches with meego-root-fs-vgrade-mods (very slow)"
    echo "     : remodify - patches with meego-root-fs-vgrade-mods (fast)"
    echo "     : remount  - just mounts /media/meego-sd (fast)"
    echo "     : umount   - umounts /media/meego-sd (fast)"
    echo " If you don't supply an <image-stub-name>, '../mg-tablet-tegra' is used"
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

if [ "$3" == "" ] ; then
    OLDIMAGE=../mg-tablet-tegra
else
    OLDIMAGE=$3
fi

if [ "$UMOUNT" = "1" ] ; then
    sync; sync; sync
    unMountIfMounted /dev/${DEVICE}1
    unMountIfMounted /dev/${DEVICE}2
    unMountIfMounted /dev/mapper/loop0p1
    unMountIfMounted /dev/mapper/loop0p2
    unMountIfMounted /dev/mapper/loop0p3
    unMountIfMounted /dev/mapper/loop0p4
    sudo kpartx -d $OLDIMAGE.img
fi

if [ "$REMOUNT" = "1" ] ; then
    sudo kpartx -v -a $OLDIMAGE.img
    PARTITIONS=`sudo kpartx -l $OLDIMAGE.img`
    PARTITION2=`echo "$PARTITIONS" | awk 'NR==2' | sed 's/\([a-z0-9]*\).*/\1/'`
    DEVICE_IMG=`echo "$PARTITIONS" | awk 'NR==2' | awk -v fld=5 '{if(NF>=fld) {print $fld} } '`
    echo DEVICE_IMG is $DEVICE_IMG and PARTITION2 is $PARTITION2
    sudo mount /dev/mapper/$PARTITION2 /media/meego/
    if [ "$REFORMAT" = "1" ] ; then
        sudo sfdisk -d $DEVICE_IMG > $OLDIMAGE.sfdisk
        if [ ! -f $OLDIMAGE.sfdisk ] ; then
            echo "Error: Couldn't open $OLDIMAGE.sfdisk!"
            exitShowingUsage
        fi
        sudo sfdisk --force /dev/${DEVICE} < $OLDIMAGE.sfdisk
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
    if [ ! -f $OLDIMAGE.img ] ; then
        echo "Error: Couldn't open $OLDIMAGE.img"
        exitShowingUsage
    fi
    if [ "$REFORMAT" = "0" -a "$RECOPY" = "1" ] ; then
        sudo rm -rf /media/meego-sd/*
    fi
fi

if [ "$COPY_VAR_LOG" = "1" -a "$REMOUNT" = "1" ] ; then
    if [ -d /tmp/meego-var-log ] ; then
        sudo rm -rf /tmp/meego-var-log
        sudo mkdir /tmp/meego-var-log
    fi
    echo "Copying /var/log to /tmp/meego-var-log"
    if [ -d /media/meego-sd/var/log ] ; then
        sudo cp -rf /media/meego-sd/var/log /tmp/meego-var-log/
        sudo chmod -R 777 /media/meego-sd/var/log /tmp/meego-var-log/
    fi
fi

if [ "$RECOPY" = "1" ] ; then
    sudo rsync -axS --exclude=/tmp/* --progress /media/meego/* /media/meego-sd
fi

if [ "$REMODIFY" = "1" ] ; then
    sudo rsync -axS --progress meego-root-fs-vgrade-mods/* /media/meego-sd
    sudo rm -rf /media/meego-sd/tmp/* || echo "/tmp already clean"
    sudo rm -rf /media/meego-sd/var/log/*.log || echo "/var/log/*.log already clean"
    sudo rm -rf /media/meego-sd/var/log/messages || echo "messages already clean"
    sudo rm -rf /media/meego-sd/etc/readahead.packed || echo "/etc/readahead.packed already clean"
fi

echo ""; echo "All done!"; echo ""

exit 0
