#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


setup_authorized_keys () {
    local username="${1}"
    local force_overwrite="${2}"

    shift 2

    [[ "${#}" -gt 0 ]] || return 1

    local home
    home=$(homedir "${username}")

    if [[ -e "${home}/.ssh/authorized_keys" ]] && ! is_true "${force_overwrite}"; then
        return 1
    fi

    cmd mkdir -p "${home}/.ssh"

    {
        for key in "${@}"; do
            printf "%s\n" "${key}"
        done

    } | to_file "${home}/.ssh/authorized_keys"

    cmd chown -R "${username}:${username}" "${home}/.ssh"
    cmd chmod 700 "${home}/.ssh"
    cmd chmod 600 "${home}/.ssh/authorized_keys"
}
