#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


setup_lv () {
    local vg="${1}"
    local lv="${2}"
    local mountpoint="${3}"
    local size="${4}"
    local filesystem="${5:-xfs}"

    local block_dev="/dev/mapper/${vg}-${lv}"

    if ! [[ -b "${block_dev}" ]]; then

        msg "Setting up ${mountpoint} block device and mount point"

        cmd lvcreate -n "${lv}" -L "${size}" "${vg}"
        cmd mkfs -t "${filesystem}" "${block_dev}"

        if ! grep -q "^${block_dev}" /etc/fstab; then
            printf '%s\t%s\t%s\tdefaults,relatime\t0 0\n' "${block_dev}" "${mountpoint}" "${filesystem}" >>/etc/fstab
        fi

        cmd mkdir -p "${mountpoint}"

        cmd mount "${mountpoint}"
    fi
}
