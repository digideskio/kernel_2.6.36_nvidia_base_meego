# -*-mic2-options-*- -f raw --save-kernel --arch=armv7hl -*-mic2-options-*-

lang en_US.UTF-8
keyboard us
timezone --utc America/Los_Angeles
auth --useshadow --enablemd5


part /msdos --size=128 --ondisk mmcblk0p --fstype=vfat
part / --size=3584 --ondisk mmcblk0p --fstype=ext4
# This partition is made so that u-boot can find the kernel
part /boot --size=64 --ondisk mmcblk0p --fstype=vfat


rootpw meego
xconfig --startxonboot
desktop --autologinuser=meego  --defaultdesktop=DUI --session="/usr/bin/mcompositor"
user --name meego  --groups audio,video --password meego


#http://download.meego.com/live/MeeGo:/1.2.0:/oss:/Update:/Testing/MeeGo_1.2.0/armv7hl/
# A recent weekly snapshot:

repo --name=oss --baseurl=http://repo.meego.com/MeeGo/snapshots/stable/1.2.0.90/1.2.0.90.12.20110810.2/repos/oss/armv7hl/packages --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
repo --name=non-oss --baseurl=http://repo.meego.com/MeeGo/snapshots/stable/1.2.0.90/1.2.0.90.12.20110810.2/repos/non-oss/armv7hl/packages --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
#repo --name=oss --baseurl=http://repo.meego.com/MeeGo/snapshots/stable/1.2.0/1.2.0.0.0.20110518.3/repos/oss/armv7hl/packages --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
#repo --name=non-oss --baseurl=http://repo.meego.com/MeeGo/snapshots/stable/1.2.0/1.2.0.0.0.20110518.3/repos/non-oss/armv7hl/packages --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
repo --name=vgrade --baseurl=http://repo.pub.meego.com/home:/vgrade/MeeGo_Trunk_standard --save --debuginfo --source

#repo --name=oss --baseurl=http://repo.meego.com/MeeGo/snapshots/stable/1.2.0.90/1.2.0.90.12.20110810.2/repos/oss/armv7hl/packages --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
#repo --name=non-oss --baseurl=http://repo.meego.com/MeeGo/snapshots/stable/1.2.0.90/1.2.0.90.12.20110810.2/repos/non-oss/armv7hl/packages --save --debuginfo --source --gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-meego
# I reenable tegralibc add --excludepkgs=glibc* to the above repo commands.
# repo --name=tegraglibc         --baseurl=http://repo.pub.meego.com/home:/vgrade:/glibc/Project_DE_MeeGo_1.2_standard/

%packages

@MeeGo Core
@MeeGo X Window System
@MeeGo Tablet
@MeeGo Tablet Applications
@MeeGo Base Development
@Development Tools
@MeeGo SDK Base
@X for Netbooks
xorg-x11-drv-mtev
qt-demos
xinput_calibrator
evtest
# Gfx accelleration - use s/w for the timebeing
mesa-dri-swrast-driver
xorg-x11-drv-fbdev
xorg-x11-drv-evdev
xorg-x11-utils-xinput
xorg-x11-utils-xev
mesa-libEGL
mesa-libGL
mesa-libGLESv2
-pulseaudio-modules-tablet-common
-pulseaudio-modules-tablet-mainvolume
-dsme
-libdsme

%end

%post
# save a little bit of space at least...
rm -f /boot/initrd*

rm -f /var/lib/rpm/__db*
rpm --rebuilddb

echo "DISPLAYMANAGER=\"uxlaunch\"" >> /etc/sysconfig/desktop
echo "session=/usr/bin/mcompositor" >> /etc/sysconfig/uxlaunch

# echo "xopts=-nocursor" >> /etc/sysconfig/uxlaunch

gconftool-2 --direct \
  --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
  -s -t string /meegotouch/target/name tablet

gconftool-2 --direct \
  --config-source xml:readwrite:/etc/gconf/gconf.xml.mandatory \
  -s -t string /meego/ux/theme 1024-600-10

gconftool-2 --direct \
  --config-source xml:readwrite:/etc/gconf/gconf.xml.defaults \
  -s -t bool /meego/ux/ShowPanelsAsHome false

# Copy boot and shutdown images
cp /usr/share/themes/1024-600-10/images/system/boot-screen.png /usr/share/plymouth/splash.png
cp /usr/share/themes/1024-600-10/images/system/shutdown-screen.png /usr/share/plymouth/shutdown-1024x600.png

%end

%post --nochroot
if [ -n "$IMG_NAME" ]; then
    echo "BUILD: $IMG_NAME" >> $INSTALL_ROOT/etc/meego-release
fi
echo 'export M_USE_SOFTWARE_RENDERING=1' >> $INSTALL_ROOT/home/meego/.bashrc
echo 'export M_USE_SHOW_CURSOR=1' >> $INSTALL_ROOT/home/meego/.bashrc

# (Advent Vega) enable host usb.
echo 'echo -e 1\n >/sys/usbbus/host_mode' >> $INSTALL_ROOT/etc/rc.d/rc.local

cat << INPUTVEGA >> $INSTALL_ROOT/etc/X11/xorg.conf.d/00-input-vega.conf
Section "InputClass"
    Identifier "default"
    driver     "evdev"
EndSection

Section "InputClass"
    Identifier      "IT7260-touchscreen"
    MatchDevicePath "/dev/input/event2"
    Driver          "mtev"
    Option          "Calibration" "0 1024 0 600"
EndSection

Section "InputClass"
    Identifier             "Mouse Defaults"
    MatchIsPointer         "yes"
EndSection

Section "InputClass"
    Identifier             "Keyboard Defaults"
    MatchIsKeyboard        "yes"
EndSection
INPUTVEGA

cat << UDEVNAME >> $INSTALL_ROOT/lib/udev/rules.d/10-input-vega.rules
DRIVER=="it7260", NAME="Touchscreen"
DRIVER=="bma150", NAME="Accelerometer"
UDEVNAME

cat << NOACCEL >> $INSTALL_ROOT/etc/X11/xorg.conf.d/80-suppress-accel.conf
# Suppress input from touch screen. hard coded to /dev/input/event3 for now.
Section "InputClass"
        Identifier	"Suppress Accelerometer input"
        MatchDevicePath "/dev/input/event3"
        Option		"Ignore" "on"
EndSection
NOACCEL

# Add Meego to sudoers list
cat << SUDOERS >> $INSTALL_ROOT/etc/sudoers
meego ALL=(ALL) ALL
SUDOERS

# Show cursor in apps.
for i in $INSTALL_ROOT/usr/share/applications/*.desktop ; do sed -i '/^Exec=/s|$| -show-cursor|' $i; done

%end
