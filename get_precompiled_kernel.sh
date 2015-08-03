#!/bin/bash
source /etc/portage/make.conf
DONTASK=0

while getopts "y" OPTION; do
	case "${OPTION}" in
		y)
			DONTASK=1
			;;
	esac
done
shift $(( OPTIND - 1 ))

if [ -z "${@}" ]; then
	KERNELVERSION="$(eix gentoo-sources | grep -v "Installed versions" | grep "(" | tail -n 1 | awk '{print $1}' | sed 's/(//g' | sed 's/)//g')"
else
	KERNELVERSION="${@}"
fi

echo "Installing precompiled kernel sys-kernel/gentoo-sources-${KERNELVERSION}"
if [ ${DONTASK} -eq 0 ]; then
	echo "Press any key to continue"
	echo "STRG + C to cancel"
	read crap
fi

TMPDIR="$(mktemp -d)"

if [ -z "$(mount | grep /boot)" ]; then 
	mount /boot || exit 1
fi

echo "Fetching kernel headers ..."
emerge -1 =sys-kernel/gentoo-sources-${KERNELVERSION}

echo "Fetching binary ..."

cd ${TMPDIR}

wget -c ${PORTAGE_BINHOST}/prebuild-kernels/gentoo-sources-${KERNELVERSION}.tar.gz
if [ ! $? -eq 0 ]; then
    wget -c ${PORTAGE_BINHOST}/prebuild-kernels/gentoo-sources-${KERNELVERSION}.tar.gz || exit 1
fi

echo "Checking Download and extracting ..."
test -f gentoo-sources-${KERNELVERSION}.tar.gz && tar xf gentoo-sources-${KERNELVERSION}.tar.gz

echo "Copying kernel configuration ..."
test -d /etc/kernels/kernel-config-x86_64-${KERNELVERSION}-gentoo-mfc || cp -pR kernel-config-x86_64-${KERNELVERSION}-gentoo-mfc /etc/kernels/
test -d /usr/src/linux-${KERNELVERSION}-gentoo/.config || cp -pR kernel-config-x86_64-${KERNELVERSION}-gentoo-mfc /usr/src/linux-${KERNELVERSION}-gentoo/.config

echo "Installing modules in /lib/modules/${KERNELVERSION}-gentoo ..."
test -d /lib/modules/${KERNELVERSION}-gentoo || cp -pR ${KERNELVERSION}-gentoo /lib/modules

echo "Installing system map System.map-genkernel-x86_64-${KERNELVERSION}-gentoo ..."
test -f /boot/System.map-genkernel-x86_64-${KERNELVERSION}-gentoo || cp -p System.map-genkernel-x86_64-${KERNELVERSION}-gentoo /boot/

echo "Installing initram disk initramfs-genkernel-x86_64-${KERNELVERSION}-gentoo ..."
test -f /boot/initramfs-genkernel-x86_64-${KERNELVERSION}-gentoo || cp -p initramfs-genkernel-x86_64-${KERNELVERSION}-gentoo /boot/

echo "Installing kernel kernel-genkernel-x86_64-${KERNELVERSION}-gentoo ..."
test -f /boot/kernel-genkernel-x86_64-${KERNELVERSION}-gentoo || cp -p kernel-genkernel-x86_64-${KERNELVERSION}-gentoo /boot/

echo "Setting new kernel as default ..."
eselect kernel set $(eselect kernel list | grep ${KERNELVERSION} | awk '{print $1}' | sed "s/\[//g" | sed "s/\]//g")

echo "Updating grub configuration..."
boot-update

echo "Preparing modules ..."
cd /usr/src/linux && make oldconfig && make modules_prepare

echo "Rebuilding module dependent packages ..."
emerge @module-rebuild

echo "Doing cleanup ..."
cd .. && rm -rf ${TMPDIR}
umount /boot

echo "Finished!!!"
echo "Installed binary kernel gentoo-sources-${KERNELVERSION}."