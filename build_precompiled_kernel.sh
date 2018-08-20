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
	KERNELVERSION="$(eix aufs-sources | egrep -v "(Installed versions|Description)" | grep "(" | tail -n 1 | awk '{print $1}' | sed 's/(//g' | sed 's/)//g')"
else
	KERNELVERSION="${@}"
fi

echo "Building precompiled kernel sys-kernel/aufs-sources-${KERNELVERSION}"
if [ ${DONTASK} -eq 0 ]; then
	echo "Press any key to continue"
	echo "STRG + C to cancel"
	read crap
fi

TMPDIR="$(mktemp -d)"
CURRENT_KERNEL="$(eselect kernel list | grep \* | awk '{print $2}' | awk -F- '{print $2}')"

echo "Fetching kernel headers ..."
emerge -1 =sys-kernel/aufs-sources-${KERNELVERSION}

echo "Setting new kernel as default ..."
eselect kernel set $(eselect kernel list | grep ${KERNELVERSION}-aufs | awk '{print $1}' | sed "s/\[//g" | sed "s/\]//g")

echo "Updating genkernel ..."
emerge -1 sys-kernel/genkernel

echo "Compiling new kernel ..."
genkernel --kernel-config=/etc/kernels/kernel-config-x86_64-${CURRENT_KERNEL}-aufs-mfc --lvm --mdadm all

if [ -z "$(mount | grep /boot)" ]; then
	mount /boot || exit 1
fi

echo "Copying kernel configuration ..."
cp -pR /etc/kernels/kernel-config-x86_64-${KERNELVERSION}-aufs-mfc ${TMPDIR}/ || exit 1

echo "Copying modules in /lib/modules/${KERNELVERSION}-aufs ..."
cp -pR /lib/modules/${KERNELVERSION}-aufs-mfc ${TMPDIR}/ || exit 1

echo "Copying system map System.map-genkernel-x86_64-${KERNELVERSION}-aufs ..."
cp -p /boot/System.map-genkernel-x86_64-${KERNELVERSION}-aufs-mfc ${TMPDIR}/ || exit 1

echo "Copying initram disk initramfs-genkernel-x86_64-${KERNELVERSION}-aufs ..."
cp -p /boot/initramfs-genkernel-x86_64-${KERNELVERSION}-aufs-mfc ${TMPDIR}/ || exit 1

echo "Copying kernel kernel-genkernel-x86_64-${KERNELVERSION}-aufs ..."
cp -p /boot/kernel-genkernel-x86_64-${KERNELVERSION}-aufs-mfc ${TMPDIR}/ || exit 1

echo "Copying vmlinux of ${KERNELVERSION}-aufs ..."
cp -p /usr/src/linux/vmlinux ${TMPDIR}/ || exit 1

echo "Creating Archive ..."
cd ${TMPDIR} && tar cpzf /usr/portage/packages/prebuild-kernels/aufs-sources-${KERNELVERSION}.tar.gz . || exit 1

echo "Doing cleanup ..."
cd .. && rm -rf ${TMPDIR}
umount /boot

echo "Finished!!!"
echo "Created binary package aufs-sources-${KERNELVERSION}.tar.gz."
