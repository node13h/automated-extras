#!/usr/bin/env bash

# MIT license
# Copyright 2017-2021 Sergej Alikov <sergej.alikov@gmail.com>


os_family () {
    if [[ -f /etc/redhat-release ]]; then
        printf 'redhat\n'
        return 0
    elif [[ -f /etc/debian_version ]]; then
        printf 'debian\n'
        return 0
    fi

    # TODO: Perhaps return 1 (see os_is_package_installed())?
}


os_id () (
    source /etc/os-release

    printf '%s\n' "$ID"
)


os_version_id () (
    source /etc/os-release

    printf '%s\n' "$VERSION_ID"
)


# FIXME: DEPRECATED
enable_epel () {
    deprecated_function

    declare os_version_id
    os_version_id=$(os_version_id)

    if ! [[ -e /etc/yum.repos.d/epel.repo ]]; then
        yum localinstall -y "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${os_version_id}.noarch.rpm"
    fi
}


os_user_exists () {
    declare username="$1"

    getent passwd "$username" >/dev/null
}


os_group_exists () {
    declare groupname="$1"

    getent group "$groupname" >/dev/null
}


os_homedir () {
    declare username="$1"

    getent passwd "$username" | cut -d ':' -f 6
}


os_is_package_installed () {
    declare package="$1"

    declare os_family
    os_family=$(os_family)

    case "$os_family" in
        'redhat')
            rpm -q "$package" --nosignature --nodigest >/dev/null
            ;;
        'debian')
            LANG=C dpkg-query -W --showformat='${db:Status-Status}\n' "$package" \
                | grep -i -x -F installed >/dev/null
            ;;
        *)
            throw "$os_family is unsupported"
            ;;
    esac
}


os_packages_ensure () {
    declare state="$1"
    shift

    declare pkg
    declare -a install_cmd
    declare -a remove_cmd

    declare os_id
    os_id=$(os_id)

    case "$os_id" in
        'centos'|'rhel')
            install_cmd=('yum' '-y' 'install')
            remove_cmd=('yum' '-y' 'remove')
            ;;
        'fedora'|'rocky')
            install_cmd=('dnf' '-y' 'install')
            remove_cmd=('dnf' '-y' 'remove')
            ;;
        'debian'|'ubuntu'|'raspbian')
            install_cmd=('apt-get' '-y' 'install')
            remove_cmd=('apt-get' '-y' 'remove')
            ;;
        *)
            throw "${os_id} is unsupported"
            ;;
    esac

    for pkg in "$@"; do
        case "$state" in
            'present')
                os_is_package_installed "$pkg" || "${install_cmd[@]}" "$pkg"
                ;;
            'absent')
                ! os_is_package_installed "$pkg" || "${remove_cmd[@]}" "$pkg"
                ;;
            *)
                throw "Unsupported state $state"
                ;;
        esac
    done
}


os_is_service_running () {
    declare service="$1"

    if systemd_is_active; then
        systemctl -q is-active "$service"
    else
        LANG=C service "$service" status | grep -F 'running' >/dev/null
    fi
}


os_service_ensure () {
    declare state="$1"
    declare service="$2"

    declare -a start_cmd
    declare -a stop_cmd
    declare -a enable_cmd
    declare -a disable_cmd

    declare os_family
    os_family=$(os_family)

    if systemd_is_active; then
        start_cmd=('systemctl' 'start' "$service")
        stop_cmd=('systemctl' 'stop' "$service")
        enable_cmd=('systemctl' 'enable' "$service")
        disable_cmd=('systemctl' 'disable' "$service")
    else
        start_cmd=('service' "$service" 'start')
        stop_cmd=('service' "$service" 'stop')

        case "$os_family" in
            'redhat')
                enable_cmd=('chkconfig' "$service" 'on')
                disable_cmd=('chkconfig' "$service" 'off')
                ;;
            'debian')
                enable_cmd=('update-rc.d' "$service" 'enable')
                disable_cmd=('update-rc.d' "$service" 'disable')
                ;;
            *)
                throw "${os_family} is unsupported"
                ;;
        esac
    fi

    case "$state" in
        'enabled')
            "${enable_cmd[@]}"
            ;;
        'disabled')
            "${disable_cmd[@]}"
            ;;
        'started')
            os_is_service_running "$service" || "${start_cmd[@]}"
            ;;
        'stopped')
            ! os_is_service_running "$service" || "${stop_cmd[@]}"
            ;;
    esac
}
