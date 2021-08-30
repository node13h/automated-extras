#!/usr/bin/env bash

# MIT license
# Copyright 2017-2021 Sergej Alikov <sergej.alikov@gmail.com>

# Examples:
#
# lvm_install_packages
# lvm_set_up_encrypted_volume_file /tmp/myvolume 5G correct-horse-battery-staple myvg
# mkfs.ext4 /dev/myvg/myvolume
# mount /dev/myvg/myvolume /mnt/myvolume



# Ensure all required packages are installed
lvm_install_packages () {
    os_packages_ensure present cryptsetup lvm2
}


# Set up an encrypted LVM physical volume with a volume group on it,
# using a loop-mounted file as the device.
#
# Do nothing if the file already exists.
lvm_set_up_encrypted_volume_file () {
    declare name="$1"
    declare file="$2"
    declare size="$3"
    declare secret="$4"
    declare vg="$5"

    declare -r dev="/dev/mapper/${name}"
    declare loop_dev

    if [[ -e "$file" ]]; then
        log_debug "Encrypted volume file ${file} has already been set up"
    else
        if [[ -e "$dev" ]]; then
            log_error "Device name ${dev} is already taken"
            return 1
        fi

        if cryptsetup status "$name" >/dev/null; then
            log_error "Some other encrypted volume with the same name (${name}) is already open"
            return 1
        fi

        log_info "Setting up secure volume at ${file}"

        declare parent_dir
        parent_dir=$(dirname "$file")

        mkdir -p "$parent_dir"

        fallocate -l "$size" "$file"

        loop_dev=$(losetup -f)

        losetup "$loop_dev" "$file"

        cryptsetup \
            open \
            --type plain \
            --key-file <(head -c 100 </dev/urandom) \
            "$loop_dev" "$name"

        dd if=/dev/zero bs=256M of="$dev" || true
        cryptsetup close "$name"

        cryptsetup \
            luksFormat \
            --type luks \
            "$loop_dev" <(printf '%s' "$secret")

        losetup -d "$loop_dev"
    fi

    if cryptsetup status "$name" >/dev/null; then
        log_debug "Encrypted volume ${name} is already open"
    else
        loop_dev=$(losetup -f)
        losetup "$loop_dev" "$file"

        cryptsetup \
            open \
            --type luks \
            --key-file <(printf '%s' "$secret") \
            "$loop_dev" "$name"
    fi

    lvm_set_up_pv "$dev"
    lvm_set_up_vg "$vg" "$dev"
}


# Create a PV if it doesn't exist already
lvm_set_up_pv () {
    declare name="$1"

    if ! lvm pvs "$name" >/dev/null 2>/dev/null; then
        pvcreate "$name"
    fi
}


# Create a VG if it doesn't exist already.
# Fail if VG does exist, but the configuration does not match the desired one.
lvm_set_up_vg () {
    declare vg_name="$1"
    declare pv_name="$2"

    declare pv_vars

    if pv_vars=$(pvs "$pv_name" --rows --noheadings --nameprefixes --unbuffered -q 2>/dev/null); then
        declare pv_vg
        pv_vg=$(set -e; eval "$pv_vars"; printf '%s\n' "$LVM2_VG_NAME")

        if [[ -n "$pv_vg" ]] && [[ "$pv_vg" != "$vg_name" ]]; then
            log_error "${pv_name} PV already exists, but is bound to a different VG ${pv_vg} (expected ${vg_name} VG)"
            return 1
        fi
    else
        log_error "${pv_name} PV does not exist"
        return 1
    fi

    if ! lvm vgs "$vg_name" >/dev/null 2>/dev/null; then
        vgcreate "$vg_name" "$pv_name"
    fi
}


# Check if LV exists
# Example: lvm_lv_exists vg0/test
lvm_lv_exists () {
    path="$1"

    lvm lvs "$path" >/dev/null 2>/dev/null
}


# FIXME: DEPRECATED
setup_lv () {
    deprecated_with_alternatives 'lvm_lv_exists()' 'lvcreate' 'mkfs' 'systemd_set_up_mount()'

    declare vg="${1}"
    declare lv="${2}"
    declare mountpoint="${3}"
    declare size="${4}"
    declare filesystem="${5:-xfs}"

    declare block_dev="/dev/mapper/${vg}-${lv}"

    if ! [[ -b "${block_dev}" ]]; then

        log_info "Setting up ${mountpoint} block device and mount point"

        lvcreate -n "${lv}" -L "${size}" "${vg}"
        mkfs -t "${filesystem}" "${block_dev}"

        if ! grep -q "^${block_dev}" /etc/fstab; then
            printf '%s\t%s\t%s\tdefaults,relatime\t0 0\n' "${block_dev}" "${mountpoint}" "${filesystem}" >>/etc/fstab
        fi

        mkdir -p "${mountpoint}"

        mount "${mountpoint}"
    fi
}
