#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


ip_to_int () {
    local ip="${1}"

    if [[ "${ip}" =~ ^([0-9]+).([0-9]+).([0-9]+).([0-9]+)$ ]]; then
        printf '%s\n' $(( BASH_REMATCH[4] + 256*BASH_REMATCH[3] + 256*256*BASH_REMATCH[2] + 256*256*256*BASH_REMATCH[1] ))
    else
        return 1
    fi
}

int_to_ip () {
    local int="${1}"

    local o1 o2 o3 o4

    o1=$(( $(( $(( $(( int/256 ))/256 ))/256 ))%256 ))
    o2=$(( $(( $(( int/256 ))/256 ))%256 ))
    o3=$(( $(( int/256 ))%256 ))
    o4=$(( int%256 ))

    printf '%s.%s.%s.%s\n' "${o1}" "${o2}" "${o3}" "${o4}"
}


ip_list_from_range () {
    local start end i

    start=$(ip_to_int "${1}")
    end=$(ip_to_int "${2}")

    for ((i = "${start}" ; i <= "${end}" ; i++)); do
        int_to_ip "${i}"
    done
}
