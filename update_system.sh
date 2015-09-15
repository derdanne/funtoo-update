#!/bin/bash
source /etc/portage/make.conf
export EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --with-bdeps=y --complete-graph --keep-going"

DONTASK=0
KERNELUPDATE=0

usage() {
cat << EOF
usage: $0 [-y] [-k [KERNELVERSION]]

This script updates your funtoo box

OPTIONS:
   -y      Do not ask any question, just keep going an do the update
   -k      Get a precompiled gentoo-sources kernel with KERNELVERSION as A.B.C
EOF
}

while getopts ":yk:" OPTION; do
    case "${OPTION}" in
        y)
            DONTASK=1
        ;;
        k)
            if [[ ${OPTARG} = -* ]]; then
                $(( OPTIND -1 ))
                continue
            fi
            if [ ! -z $OPTARG  ]; then
                KERNELVERSION="${OPTARG}"
            fi
            KERNELUPDATE=1
        ;;
        :)
            case ${OPTARG} in
                k)
                    KERNELUPDATE="1"
                ;;
            esac
        ;;
        \?)
            usage
            exit 0
        ;;
    esac
done
shift $(( OPTIND - 1 ))

tput setf 2
echo "Syncing Portage Trees"
tput sgr0

emerge --sync || exit 1
eix-update || exit 1
/server/admin/script/maint/update_mfc_portage_overlay.sh || exit 1

tput setf 2
echo "Updating Portage to latest version..."
tput sgr0

emerge --oneshot portage || exit 1

if [ ${DONTASK} -eq 0 ]; then
    ASK="--ask"
fi

tput setf 2
echo "Doing system updates..."
tput sgr0
emerge -uND ${ASK} @world || exit 1

tput setf 2
echo "Emerging preserved rebuild set..."
tput sgr0
emerge ${ASK} @preserved-rebuild || exit 1

tput setf 2
echo "Emerging module rebuild set..."
tput sgr0
emerge ${ASK} @module-rebuild || exit 1

tput setf 2
echo "Checking reverse dependencies..."
tput sgr0
revdep-rebuild -- ${ASK} || exit 1

tput setf 2
echo "Doing perl cleanup..."
tput sgr0
perl-cleaner --all -- ${ASK} || exit 1

if [ ${KERNELUPDATE} -eq 1 ]; then
    if [ ${DONTASK} -eq 1 ]; then
        ASK="-y"
    fi
    tput setf 2
    echo "Updating kernel..."
    tput sgr0
    get_precompiled_kernel ${ASK} ${KERNELVERSION} || exit 1
fi

exit 0
