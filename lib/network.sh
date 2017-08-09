#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


setup_port_forward () {
    local public_address="${1}"
    local public_port="${2}"
    local inside_address="${3}"
    local inside_port="${4}"
    local zone="${5:-public}"

    msg "Setting up port forward from port ${public_port} to the ${inside_address}:${inside_port}"

    cmd firewall-cmd --zone="${zone}" --add-rich-rule="rule family=ipv4 destination address=${public_address} forward-port port=${public_port} protocol=tcp to-port=${inside_port} to-addr=${inside_address}"
    cmd firewall-cmd --zone="${zone}" --permanent --add-rich-rule="rule family=ipv4 destination address=${public_address} forward-port port=${public_port} protocol=tcp to-port=${inside_port} to-addr=${inside_address}"
}
