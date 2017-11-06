#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


enable_epel () {
    if ! [[ -e /etc/yum.repos.d/epel.repo ]]; then
        cmd yum localinstall -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${FACT_OS_VERSION}.noarch.rpm"
    fi
}

user_exists () {
    local username="${1}"

    getent passwd "${username}" >/dev/null
}

group_exists () {
    local groupname="${1}"

    getent group "${groupname}" >/dev/null
}

homedir () {
    local username="${1}"

    getent passwd "${username}" | cut -d ':' -f 6
}

quoted_for_systemd () {
    local arg
    local -a result=()

    for arg in "${@}"; do
        # shellcheck disable=SC1003
        result+=("\"$(translated "${arg}" '\' '\\' '"' '\"')\"")
    done

    printf '%s\n' "${result[*]}"
}

packages_ensure () {
    local command="${1}"
    shift

    case "${FACT_OS_FAMILY}-${command}" in
        'RedHat-present')
            cmd yum -y install "${@}"
            ;;
        'RedHat-absent')
            cmd yum -y remove "${@}"
            ;;
        'Debian-present')
            cmd apt-get -y install "${@}"
            ;;
        'Debian-absent')
            cmd apt-get -y remove "${@}"
            ;;
        *)
            throw "Command ${command} is unsupported on ${FACT_OS_FAMILY}"
            ;;
    esac
}

service_ensure () {
    local command="${1}"
    local service="${2}"

    if is_true "${FACT_SYSTEMD}"; then
        case "${command}" in
            enabled)
                cmd systemctl enable "${service}"
                ;;
            disabled)
                cmd systemctl disable "${service}"
                ;;
        esac
    else
        case "${FACT_OS_FAMILY}-${command}" in
            'RedHat-enabled')
                cmd chkconfig "${service}" on
                ;;
            'RedHat-disabled')
                cmd chkconfig "${service}" off
                ;;
            'Debian-enabled')
                cmd update-rc.d "${service}" enable
                ;;
            'Debian-disabled')
                cmd update-rc.d "${service}" disable
                ;;
            *)
                throw "Command ${command} is unsupported on ${FACT_OS_FAMILY}"
                ;;
        esac
    fi
}
