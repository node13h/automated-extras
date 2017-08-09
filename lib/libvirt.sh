#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


libvirt_uuid () {
    local class="${1}"
    local name="${2}"
    local uuid

    uuid=$(virsh "${class}-uuid" "${name}" 2>/dev/null) || uuid=$(python -c 'import uuid; print str(uuid.uuid1())')

    printf "%s\n" "${uuid}"
}

libvirt_polkit_manage_rules () {
    cat <<EOF
polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" && subject.active && subject.isInGroup("wheel")) {
      return polkit.Result.YES;
  }
});
EOF
}

setup_libvirt_polkit_manage_rules () {
    msg "Setting up PolicyKit to allow wheel group users to connect to libvirt"

    libvirt_polkit_manage_rules | to_file '/etc/polkit-1/rules.d/80-libvirt-manage.rules'
}
