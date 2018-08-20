#!/bin/bash
source /etc/portage/make.conf
export EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --with-bdeps=y --complete-graph --keep-going --autounmask-keep-masks --backtrack=9999 --exclude=sys-kernel/gentoo-sources --exclude=sys-kernel/aufs-sources"

DONTASK=0
DEEP=0
MIGRATE=0
KERNELUPDATE=0
REBOOT=0

usage() {
cat << EOF
usage: $0 [-y] [-d] [-k [KERNELVERSION]] [-m] [-r]

This script updates your funtoo box

OPTIONS:
   -y      Do not ask any question, just keep going an do the update
   -d      Do a really deep Update
   -k      Get a precompiled gentoo-sources kernel with KERNELVERSION as A.B.C
   -m      Migration Scripts (currently: MySQL, Apache)
   -r      Do a reboot after updating System
EOF
}

if [ -z "$STY" ] && [ "$(tty -s && echo $?)" -eq 0 ] ; then
    echo "logfile /var/log/screen.log" > /tmp/screenrc.$$
    exec screen -c /tmp/screenrc.$$ -L -m -S screenName /bin/bash "$0" "$@"
    rm /tmp/screenrc.$$
fi

while getopts ":ydmrk:" OPTION; do
    case "${OPTION}" in
        y)
            DONTASK=1
        ;;
        d)
            DEEP=1
        ;;
        k)
            if [[ ${OPTARG} = -* ]]; then
                $(( OPTIND -1 ))
                continue
            fi
            if [ ! -z ${OPTARG}  ]; then
                KERNELVERSION="${OPTARG}"
            fi
            KERNELUPDATE=1
        ;;
        :)
            case ${OPTARG} in
                k)
                    KERNELUPDATE=1
                ;;
            esac
        ;;
        m)
            MIGRATE=1
        ;;
        r)
            REBOOT=1
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

test -f /usr/local/bin/update_kits && /usr/local/bin/update_kits &>/dev/null || ego sync &>/dev/null
eselect news read --quiet all

tput setf 2
echo "Updating Portage to latest version..."
tput sgr0

emerge -u -q --oneshot --autounmask-keep-masks portage || exit 1
emerge -u -q --oneshot --autounmask-keep-masks app-admin/ego || exit 1
epro update || exit 1

if [ ${DONTASK} -eq 0 ]; then
    ASK="--ask"
fi

tput setf 2
echo "Doing system updates..."
tput sgr0
emerge -quND ${ASK} @world || exit 1
emerge -quND ${ASK} dev-lang/php || exit 1

if [ ${DEEP} -eq 1 ]; then
    tput setf 2
    echo "Doing Deep system updates..."
    tput sgr0
    for PACKAGE in $(EIX_LIMIT=0 eix | egrep '\[U' | awk '{print $2}'); do
        PACKAGES="${PACKAGE} ${PACKAGES}"
    done
    emerge ${ASK} -u1 ${PACKAGES} || exit 1
fi

tput setf 2
echo "Emerging preserved rebuild set..."
tput sgr0
emerge -q --usepkg-exclude="*" ${ASK} @preserved-rebuild || exit 1

tput setf 2
echo "Checking reverse dependencies..."
tput sgr0
revdep-rebuild -- ${ASK} -q --usepkg-exclude="*" || exit 1

tput setf 2
echo "Doing perl cleanup..."
tput sgr0
perl-cleaner --all -- ${ASK} -q || exit 1

if [ ${KERNELUPDATE} -eq 1 ]; then
    if [ ${DONTASK} -eq 1 ]; then
        ASK="-y"
    fi
    tput setf 2
    echo "Updating kernel..."
    tput sgr0
    get_precompiled_kernel_aufs ${ASK} ${KERNELVERSION} || exit 1
fi

if [ ${MIGRATE} -eq 1 ]; then
    if [ ${DONTASK} -eq 0 ]; then
        tput setf 2
        echo "Press any key to start migrations ..."
        tput sgr0
        read CRAP
    fi
    if [ -f "/run/mysqld/mysqld.pid" ]; then
        (   service mysql restart && \
            mysql_upgrade && \
            service mysql restart \
        )
    fi
    if [ -f "/run/apache2.pid" ]; then
        ( apache2ctl configtest && service apache2 restart ) || exit 1
    fi
fi

tput setf 2
echo "Cleanup Packages, Distfiles and old Kernels ..."
tput sgr0

eclean-pkg -q -d
eclean-dist -q -d
for KERNEL in $(ls --ignore="linux" --sort=time /usr/src/ | grep linux- | tail -n +3); do
    EBUILD="$(equery -q b /usr/src/${KERNEL} 2>/dev/null)"
    test ! -z ${EBUILD} && emerge --unmerge "=${EBUILD}"
    rm -rf /usr/src/${KERNEL}
done

if [ ${REBOOT} -eq 1 ]; then
    if [ ${DONTASK} -eq 0 ]; then
        tput setf 2
        echo "Press any key to reboot ..."
        tput sgr0
        read CRAP
    fi
    reboot
else
  rc-service puppet restart
fi

