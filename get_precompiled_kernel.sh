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

echo "Installing precompiled kernel sys-kernel/aufs-sources-${KERNELVERSION}"
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
emerge -1 =sys-kernel/aufs-sources-${KERNELVERSION}

echo "Fetching binary ..."

cd ${TMPDIR}

wget -c ${PORTAGE_BINHOST}/prebuild-kernels/aufs-sources-${KERNELVERSION}.tar.gz
if [ ! $? -eq 0 ]; then
    wget -c ${PORTAGE_BINHOST}/prebuild-kernels/aufs-sources-${KERNELVERSION}.tar.gz || exit 1
fi

echo "Checking Download and extracting ..."
test -f aufs-sources-${KERNELVERSION}.tar.gz && tar xf aufs-sources-${KERNELVERSION}.tar.gz

echo "Copying kernel configuration ..."
cp -pR kernel-config-x86_64-${KERNELVERSION}-aufs-mfc /etc/kernels/
cp -p kernel-config-x86_64-${KERNELVERSION}-aufs-mfc /usr/src/linux-${KERNELVERSION}-aufs/.config

echo "Installing modules in /lib/modules/${KERNELVERSION}-aufs ..."
cp -pR ${KERNELVERSION}-aufs-mfc /lib/modules

echo "Installing system map System.map-genkernel-x86_64-${KERNELVERSION}-aufs ..."
cp -p System.map-genkernel-x86_64-${KERNELVERSION}-aufs-mfc /boot/

echo "Installing initram disk initramfs-genkernel-x86_64-${KERNELVERSION}-aufs ..."
cp -p initramfs-genkernel-x86_64-${KERNELVERSION}-aufs-mfc /boot/

echo "Installing kernel kernel-genkernel-x86_64-${KERNELVERSION}-aufs ..."
cp -p kernel-genkernel-x86_64-${KERNELVERSION}-aufs-mfc /boot/

echo "Setting new kernel as default ..."
eselect kernel set $(eselect kernel list | grep ${KERNELVERSION} | awk '{print $1}' | sed "s/\[//g" | sed "s/\]//g")

echo "Installing vmlinux and System Map of ${KERNELVERSION}-aufs ..."
cp -p vmlinux /usr/src/linux/
cp -p System.map-genkernel-x86_64-${KERNELVERSION}-aufs-mfc /usr/src/linux/System.map

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
echo "Installed binary kernel aufs-sources-${KERNELVERSION}."
