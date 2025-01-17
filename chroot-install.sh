#!/bin/bash
set -e

MIRROR=${MIRROR:='http://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch'}
DESKTOP_LXQT=(lxqt)
DESKTOP_DDE=(deepin deepin-extra)

GUIPKGS=(qemu ovmf \
	ttf-droid ttf-dejavu \
	xorg-server xorg-xrandr xorg-xrdb xorg-xev xorg-setxkbmap xorg-setxkbmap xorg-drivers xorg-xinit
	gparted firefox pidgin pidgin-otr pidgin-xmpp-receipts element-desktop
	leafpad
	network-manager-applet
	fcitx-im fcitx-sunpinyin fcitx-configtool)

case "${DESKTOP}" in
	no)
		DESKTOP=()
		;;
	mate)
		DESKTOP=(mate mate-terminal)
		;;
	xfce*)
		DESKTOP=(xfce4)
		;;
	lxde-gtk3)
		DESKTOP=(lxde-common lxlauncher-gtk3 lxpanel-gtk3 lxsession-gtk3 lxterminal openbox pcmanfm-gtk3)
		;;
	lxqt)
		DESKTOP=("${DESKTOP_LXQT[@]}")
		;;
	dde)
		DESKTOP=("${DESKTOP_DDE[@]}")
		;;
	budgie)
		DESKTOP=(budgie-desktop)
		;;
	*)
		DESKTOP=()
		;;
esac

if [[ "${#DESKTOP[@]}" -ne 0 ]]; then
	DESKTOP+=("${GUIPKGS[@]}")
fi

pacman-key --init
pacman-key --populate archlinux

cp /etc/pacman.conf /etc/pacman.conf.bak
sed -i 's/CheckSpace/#CheckSpace/g' /etc/pacman.conf

cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
echo "Server = ${MIRROR}" > /etc/pacman.d/mirrorlist

# (re)install linux because the Linux image is not present
pacman --noconfirm -Sy linux
pacman --noconfirm -Syu --needed \
	base-devel \
	git \
	lzip \
	archiso \
	wireguard-tools \
	flashrom debootstrap htop \
	acpid iasl dmidecode procinfo-ng efibootmgr \
	picocom \
	bash-completion zsh-completions \
	networkmanager \
	chntpw radare2 \
	fwupd \
	wimlib \
	"${DESKTOP[@]}"

# rm archinstall to install the git version
pacman -R --noconfirm archinstall

if /bin/ls /aur/*.pkg.tar.*; then
	pacman --noconfirm -U --needed /aur/*.pkg.tar.*
fi

# wireguard modules has been built, remove dkms and linux-headers
#pacman --noconfirm -Rdd dkms
#pacman --noconfirm -Rcsn linux-headers

mkinitcpio -p linux

mv /etc/pacman.conf.bak /etc/pacman.conf
mv /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist

if ! grep '^chingnux:' /etc/passwd; then
	useradd -m -G wheel,uucp chingnux
	echo chingnux:chingnux | chpasswd
	sed -i 's/^# %wheel/%wheel/g' /etc/sudoers
	sed -i 's/root/chingnux/g' /etc/systemd/system/getty@tty1.service.d/autologin.conf
fi

gpgconf --homedir /etc/pacman.d/gnupg/ --kill gpg-agent || echo 'Failed to kill gpg-agent'
rm -f /etc/udev/rules.d/81-dhcpcd.rules

systemctl enable NetworkManager
systemctl enable acpid

# save the kernel package
cp "/var/cache/pacman/pkg/linux-$(pacman -Q linux|cut -d ' ' -f2)-x86_64.pkg.tar.zst" /opt/

cat >> /etc/environment << EOF
XMODIFIERS="@im=fcitx"
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
EOF
