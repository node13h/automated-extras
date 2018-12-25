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

is_package_installed () {
    local package="${1}"

    case "${FACT_OS_FAMILY}" in
        'RedHat')
            rpm -q "${package}" --nosignature --nodigest >/dev/null
            ;;
        'Debian')
            LANG=C dpkg-query --show --showformat='${Status}\n' "${package}" | grep -F installed >/dev/null
            ;;
        *)
            throw "${FACT_OS_FAMILY} is unsupported"
            ;;
    esac
}

packages_ensure () {
    local state="${1}"
    shift

    local pkg
    local -a install_cmd
    local -a remove_cmd

    case "${FACT_OS_NAME}" in
        'CentOS'|'RHEL')
            install_cmd=('yum' '-y' 'install')
            remove_cmd=('yum' '-y' 'remove')
            ;;
        'Fedora')
            install_cmd=('dnf' '-y' 'install')
            remove_cmd=('dnf' '-y' 'remove')
            ;;
        'Debian'|'Ubuntu')
            install_cmd=('apt-get' '-y' 'install')
            remove_cmd=('apt-get' '-y' 'remove')
            ;;
        *)
            throw "${FACT_OS_NAME} is unsupported"
            ;;
    esac

    for pkg in "${@}"; do
        case "${state}" in
            'present')
                is_package_installed "${pkg}" || cmd "${install_cmd[@]}" "${pkg}"
                ;;
            'absent')
                ! is_package_installed "${pkg}" || cmd "${remove_cmd[@]}" "${pkg}"
                ;;
            *)
                throw "Unsupported state ${state}"
                ;;
        esac
    done
}

is_service_running () {
    local service="${1}"

    if is_true "${FACT_SYSTEMD}"; then
        systemctl -q is-active "${service}"
    else
        LANG=C service "${service}" status | grep -F 'running' >/dev/null
    fi
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
