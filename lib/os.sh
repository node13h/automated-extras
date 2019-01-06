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
        'Debian'|'Ubuntu'|'Raspbian GNU/Linux')
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
    local state="${1}"
    local service="${2}"

    local -a start_cmd
    local -a stop_cmd
    local -a enable_cmd
    local -a disable_cmd

    if is_true "${FACT_SYSTEMD}"; then
        start_cmd=('systemctl' 'start' "${service}")
        stop_cmd=('systemctl' 'stop' "${service}")
        enable_cmd=('systemctl' 'enable' "${service}")
        disable_cmd=('systemctl' 'disable' "${service}")
    else
        start_cmd=('service' "${service}" 'start')
        stop_cmd=('service' "${service}" 'stop')

        case "${FACT_OS_FAMILY}" in
            'RedHat')
                enable_cmd=('chkconfig' "${service}" 'on')
                disable_cmd=('chkconfig' "${service}" 'off')
                ;;
            'Debian')
                enable_cmd=('update-rc.d' "${service}" 'enable')
                disable_cmd=('update-rc.d' "${service}" 'disable')
                ;;
            *)
                throw "${FACT_OS_FAMILY} is unsupported"
                ;;
        esac
    fi

    case "${state}" in
        'enabled')
            cmd "${enable_cmd[@]}"
            ;;
        'disabled')
            cmd "${disable_cmd[@]}"
            ;;
        'started')
            is_service_running "${service}" || cmd "${start_cmd[@]}"
            ;;
        'stopped')
            ! is_service_running "${service}" || cmd "${stop_cmd[@]}"
            ;;
    esac
}
