#!/usr/bin/env sh

# RHEL:
# CentOS 7 + 8 + 9
# Oracle Linux 7 + 8
# RHEL 7 + 8
# AlmaLinux
# Rocky Linux
# VZLinux
# CloudLinux
# Fedora

# Ubuntu:
# Ubuntu 18.04, 20.04, 22.04
# Debian 9, 10, 11

detect_os () {
    if [ -f '/etc/os-release' ] ; then
        REPO_OS=$(cat /etc/os-release |  grep '^ID=' | head -n1 | awk -F '=' '{print $2}' | tr -d '"')
        REPO_VER=$(cat /etc/os-release |  grep '^VERSION_ID=' | head -n1 | awk -F '=' '{print $2}' | tr -d '"')
        if [ "${REPO_OS}" = 'debian' ] || [ "${REPO_OS}" = 'ubuntu' ] ; then
            REPO_OS_CODENAME=$(cat /etc/os-release |  grep '^VERSION_CODENAME=' | head -n1 | awk -F '=' '{print $2}' | tr -d '"')
        fi
    elif [ -f '/etc/redhat-release' ] ; then
        REPO_OS=$(cat /etc/redhat-release | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
        REPO_VER=$(cat /etc/redhat-release | grep -Eo '[0-9]+([.][0-9]+)?([.][0-9]+)?')
    elif [ -f '/etc/lsb-release' ] ; then
        REPO_OS=$(cat /etc/lsb-release | grep '^DISTRIB_ID=' | awk -F '=' '{print $2}')
        REPO_VER=$(cat /etc/lsb-release | grep '^DISTRIB_RELEASE=' | awk -F '=' '{print $2}')
        REPO_OS_CODENAME=$(cat /etc/lsb-release | grep '^DISTRIB_CODENAME=' | awk -F '=' '{print $2}')
    else
        echo 'Cannot detect the operating system!'
        exit 1
    fi

    if [ "${REPO_OS}" = 'centos' ] || [ "${REPO_OS}" = 'rhel' ] || [ "${REPO_OS}" = 'rocky' ] || [ "${REPO_OS}" = 'almalinux' ] || [ "${REPO_OS}" = 'oracle' ] || [ "${REPO_OS}" = 'redhat' ] || [ "${REPO_OS}" = 'virtuozzo' ] || [ "${REPO_OS}" = 'cloudlinux' ] || [ "${REPO_OS}" = 'fedora' ]; then
        REPO_BASE_OS='centos'
        REPO_OS_VER=$(echo ${REPO_VER} | cut -c1-1)
        if [ "${REPO_OS}" = 'fedora' ]; then
            echo "Detect ${REPO_OS}, treat it as CentOS8."
            REPO_OS_VER=8
        fi
    elif [ "${REPO_OS}" = 'debian' ] || [ "${REPO_OS}" = 'ubuntu' ] ; then
        REPO_BASE_OS='debian'
    else
        echo "Non-supported operating system: ${REPO_OS}"
        exit 1
    fi

    REPO_ARCH=$(uname -m)
    if [ "${REPO_ARCH}" != 'x86_64' ] ; then
        echo "Non-supported architecture: ${REPO_ARCH}"
        exit 1
    fi
}

check_install () {
    if [ "${REPO_BASE_OS}" = 'centos' ] ; then
        if [ -f '/etc/yum.repos.d/litespeed.repo' ] ; then
            echo 'LiteSpeed repository already setup!'
            exit 1
        fi
    elif [ "${REPO_BASE_OS}" = 'debian' ] ; then
        if [ -f '/etc/apt/sources.list.d/lst_debian_repo.list' ] ; then
            echo 'LiteSpeed repository already setup!'
            exit 1
        fi
    fi
}

clean_install () {
    if [ "${REPO_BASE_OS}" = 'centos' ] ; then
        if [ -f '/etc/yum.repos.d/litespeed.repo' ] ; then
            rm -f /etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed
            rm -f //etc/yum.repos.d/litespeed.repo
            echo 'LiteSpeed repository has been removed!'
            exit 0
        fi
    elif [ "${REPO_BASE_OS}" = 'debian' ] ; then
        if [ -f '/etc/apt/sources.list.d/lst_debian_repo.list' ] ; then
            rm -f /etc/apt/trusted.gpg.d/lst_debian_repo.gpg
            rm -f /etc/apt/trusted.gpg.d/lst_repo.gpg
            rm -f /etc/apt/sources.list.d/lst_debian_repo.list
            echo 'LiteSpeed repository has been removed!'
            exit 0
        fi
    fi
}

centos_install_epel () {
    sudo yum install epel-release -y
}

centos_install_remi () {
    sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-${REPO_VER}.rpm -y
}

fedora_install_remi(){
    dnf install https://rpms.remirepo.net/fedora/remi-release-${REPO_VER}.rpm -y
}

setup_rhel () {
    # Install the GPG key
    pushd /tmp/
    curl -O https://rpms.litespeedtech.com/centos/RPM-GPG-KEY-litespeed
    mv RPM-GPG-KEY-litespeed /etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed
    popd

    # Install the repo file
    cat <<EOF >> /etc/yum.repos.d/litespeed.repo
[litespeed]
name=LiteSpeed Tech Repository for CentOS ${REPO_OS_VER} - ${REPO_ARCH}
baseurl=http://rpms.litespeedtech.com/centos/${REPO_OS_VER}/${REPO_ARCH}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed

[litespeed-update]
name=LiteSpeed Tech Update Repository for CentOS ${REPO_OS_VER} - ${REPO_ARCH}
baseurl=http://rpms.litespeedtech.com/centos/${REPO_OS_VER}/update/${REPO_ARCH}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed

[litespeed-edge]
name=LiteSpeed Tech Edge Repository for CentOS ${REPO_OS_VER} - ${REPO_ARCH}
baseurl=http://rpms.litespeedtech.com/edge/centos/${REPO_OS_VER}/${REPO_ARCH}/
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed
EOF

    echo 'LiteSpeed repository has been setup!'
}

setup_debian () {
    wget -O /etc/apt/trusted.gpg.d/lst_debian_repo.gpg http://rpms.litespeedtech.com/debian/lst_debian_repo.gpg
    wget -O /etc/apt/trusted.gpg.d/lst_repo.gpg http://rpms.litespeedtech.com/debian/lst_repo.gpg
    echo "deb http://rpms.litespeedtech.com/debian/ ${REPO_OS_CODENAME} main" > /etc/apt/sources.list.d/lst_debian_repo.list
    echo "#deb http://rpms.litespeedtech.com/edge/debian/ ${REPO_OS_CODENAME} main" >> /etc/apt/sources.list.d/lst_debian_repo.list
    echo 'LiteSpeed repository has been setup!'
}

install_repo () {
    if [ "${REPO_BASE_OS}" = 'centos' ] ; then
        setup_rhel
    elif [ "${REPO_BASE_OS}" = 'debian' ] ; then
        setup_debian
    fi
}

install_php_repo () {

    if [ "${REPO_BASE_OS}" = 'centos' ] ; then
        echo 'Install ext PHP repo.'
        if [ "${REPO_VER}" = '7' ]; then
            centos_install_epel
        elif [ "${REPO_VER}" = '8' ]; then
            centos_install_epel
        else
            if [ "${REPO_OS}" = 'fedora' ]; then
                fedora_install_remi
            else
                centos_install_remi
            fi
        fi
    fi
}

main () {
    detect_os
    if [ "${1}" = 'clean' ] ; then
        clean_install
    fi
    check_install
    install_repo
    install_php_repo
}

main "$@"
exit 0
root@oracle4:/opt# vi litespeed.sh
root@oracle4:/opt# cat litespeed.sh
#!/usr/bin/env sh

# RHEL:
# CentOS 7 + 8 + 9
# Oracle Linux 7 + 8
# RHEL 7 + 8
# AlmaLinux
# Rocky Linux
# VZLinux
# CloudLinux
# Fedora

# Ubuntu:
# Ubuntu 18.04, 20.04, 22.04
# Debian 9, 10, 11

detect_os () {
    if [ -f '/etc/os-release' ] ; then
        REPO_OS=$(cat /etc/os-release |  grep '^ID=' | head -n1 | awk -F '=' '{print $2}' | tr -d '"')
        REPO_VER=$(cat /etc/os-release |  grep '^VERSION_ID=' | head -n1 | awk -F '=' '{print $2}' | tr -d '"')
        if [ "${REPO_OS}" = 'debian' ] || [ "${REPO_OS}" = 'ubuntu' ] ; then
            REPO_OS_CODENAME=$(cat /etc/os-release |  grep '^VERSION_CODENAME=' | head -n1 | awk -F '=' '{print $2}' | tr -d '"')
        fi
    elif [ -f '/etc/redhat-release' ] ; then
        REPO_OS=$(cat /etc/redhat-release | awk '{print $1}' | tr '[:upper:]' '[:lower:]')
        REPO_VER=$(cat /etc/redhat-release | grep -Eo '[0-9]+([.][0-9]+)?([.][0-9]+)?')
    elif [ -f '/etc/lsb-release' ] ; then
        REPO_OS=$(cat /etc/lsb-release | grep '^DISTRIB_ID=' | awk -F '=' '{print $2}')
        REPO_VER=$(cat /etc/lsb-release | grep '^DISTRIB_RELEASE=' | awk -F '=' '{print $2}')
        REPO_OS_CODENAME=$(cat /etc/lsb-release | grep '^DISTRIB_CODENAME=' | awk -F '=' '{print $2}')
    else
        echo 'Cannot detect the operating system!'
        exit 1
    fi

    if [ "${REPO_OS}" = 'centos' ] || [ "${REPO_OS}" = 'rhel' ] || [ "${REPO_OS}" = 'rocky' ] || [ "${REPO_OS}" = 'almalinux' ] || [ "${REPO_OS}" = 'oracle' ] || [ "${REPO_OS}" = 'redhat' ] || [ "${REPO_OS}" = 'virtuozzo' ] || [ "${REPO_OS}" = 'cloudlinux' ] || [ "${REPO_OS}" = 'fedora' ]; then
        REPO_BASE_OS='centos'
        REPO_OS_VER=$(echo ${REPO_VER} | cut -c1-1)
        if [ "${REPO_OS}" = 'fedora' ]; then
            echo "Detect ${REPO_OS}, treat it as CentOS8."
            REPO_OS_VER=8
        fi
    elif [ "${REPO_OS}" = 'debian' ] || [ "${REPO_OS}" = 'ubuntu' ] ; then
        REPO_BASE_OS='debian'
    else
        echo "Non-supported operating system: ${REPO_OS}"
        exit 1
    fi

    REPO_ARCH=$(uname -m)
    if [ "${REPO_ARCH}" != 'x86_64' ] ; then
        echo "Non-supported architecture: ${REPO_ARCH}"
        exit 1
    fi
}

check_install () {
    if [ "${REPO_BASE_OS}" = 'centos' ] ; then
        if [ -f '/etc/yum.repos.d/litespeed.repo' ] ; then
            echo 'LiteSpeed repository already setup!'
            exit 1
        fi
    elif [ "${REPO_BASE_OS}" = 'debian' ] ; then
        if [ -f '/etc/apt/sources.list.d/lst_debian_repo.list' ] ; then
            echo 'LiteSpeed repository already setup!'
            exit 1
        fi
    fi
}

clean_install () {
    if [ "${REPO_BASE_OS}" = 'centos' ] ; then
        if [ -f '/etc/yum.repos.d/litespeed.repo' ] ; then
            rm -f /etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed
            rm -f //etc/yum.repos.d/litespeed.repo
            echo 'LiteSpeed repository has been removed!'
            exit 0
        fi
    elif [ "${REPO_BASE_OS}" = 'debian' ] ; then
        if [ -f '/etc/apt/sources.list.d/lst_debian_repo.list' ] ; then
            rm -f /etc/apt/trusted.gpg.d/lst_debian_repo.gpg
            rm -f /etc/apt/trusted.gpg.d/lst_repo.gpg
            rm -f /etc/apt/sources.list.d/lst_debian_repo.list
            echo 'LiteSpeed repository has been removed!'
            exit 0
        fi
    fi
}

centos_install_epel () {
    sudo yum install epel-release -y
}

centos_install_remi () {
    sudo dnf install https://rpms.remirepo.net/enterprise/remi-release-${REPO_VER}.rpm -y
}

fedora_install_remi(){
    dnf install https://rpms.remirepo.net/fedora/remi-release-${REPO_VER}.rpm -y
}

setup_rhel () {
    # Install the GPG key
    pushd /tmp/
    curl -O https://rpms.litespeedtech.com/centos/RPM-GPG-KEY-litespeed
    mv RPM-GPG-KEY-litespeed /etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed
    popd

    # Install the repo file
    cat <<EOF >> /etc/yum.repos.d/litespeed.repo
[litespeed]
name=LiteSpeed Tech Repository for CentOS ${REPO_OS_VER} - ${REPO_ARCH}
baseurl=http://rpms.litespeedtech.com/centos/${REPO_OS_VER}/${REPO_ARCH}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed

[litespeed-update]
name=LiteSpeed Tech Update Repository for CentOS ${REPO_OS_VER} - ${REPO_ARCH}
baseurl=http://rpms.litespeedtech.com/centos/${REPO_OS_VER}/update/${REPO_ARCH}/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed

[litespeed-edge]
name=LiteSpeed Tech Edge Repository for CentOS ${REPO_OS_VER} - ${REPO_ARCH}
baseurl=http://rpms.litespeedtech.com/edge/centos/${REPO_OS_VER}/${REPO_ARCH}/
enabled=0
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-litespeed
EOF

    echo 'LiteSpeed repository has been setup!'
}

setup_debian () {
    wget -O /etc/apt/trusted.gpg.d/lst_debian_repo.gpg http://rpms.litespeedtech.com/debian/lst_debian_repo.gpg
    wget -O /etc/apt/trusted.gpg.d/lst_repo.gpg http://rpms.litespeedtech.com/debian/lst_repo.gpg
    echo "deb http://rpms.litespeedtech.com/debian/ ${REPO_OS_CODENAME} main" > /etc/apt/sources.list.d/lst_debian_repo.list
    echo "#deb http://rpms.litespeedtech.com/edge/debian/ ${REPO_OS_CODENAME} main" >> /etc/apt/sources.list.d/lst_debian_repo.list
    echo 'LiteSpeed repository has been setup!'
}

install_repo () {
    if [ "${REPO_BASE_OS}" = 'centos' ] ; then
        setup_rhel
    elif [ "${REPO_BASE_OS}" = 'debian' ] ; then
        setup_debian
    fi
}

install_php_repo () {

    if [ "${REPO_BASE_OS}" = 'centos' ] ; then
        echo 'Install ext PHP repo.'
        if [ "${REPO_VER}" = '7' ]; then
            centos_install_epel
        elif [ "${REPO_VER}" = '8' ]; then
            centos_install_epel
        else
            if [ "${REPO_OS}" = 'fedora' ]; then
                fedora_install_remi
            else
                centos_install_remi
            fi
        fi
    fi
}

main () {
    detect_os
    if [ "${1}" = 'clean' ] ; then
        clean_install
    fi
    check_install
    install_repo
    install_php_repo
}

main "$@"
exit 0
