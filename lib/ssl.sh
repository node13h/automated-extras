#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


ssl_selfsigned_extfile () {
    local IFS

    cat <<EOF
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints=CA:true
EOF
    IFS=','
    printf 'subjectAltName=%s\n' "${*}"
}

ensure_dhparam_exists () {
    local dhparam_path="${1}"
    local dhparam_bits="${2}"

    [[ -f "${dhparam_path}" ]] || cmd openssl dhparam -out "${dhparam_path}" "${dhparam_bits}"
}

ensure_ssl_cert_exists () {
    local cert_path="${1}"
    local csr_path="${2}"
    local key_path="${3}"
    local key_owner="${4}"
    local key_group="${5}"
    local key_bits="${6}"
    local common_name="${7}"
    shift 7

    # The rest of the arguments are subjectAltNames,
    # like DNS:example.com DNS:www.example.com and so on

    local -a sign_args=(x509 -req -days 3650 -signkey "${key_path}" -in "${csr_path}" -out "${cert_path}")

    if ! [[ -f "${cert_path}" ]]; then
        msg "Creating SSL certificate/key pair for ${key_owner}:${key_group}"

        (
            umask 0277
            cmd openssl genrsa -out "${key_path}" "${key_bits}"
        )

        cmd openssl req -new -key "${key_path}" -out "${csr_path}" -subj "/CN=${common_name}" -batch

        if [[ "${#}" -gt 0 ]]; then
            cmd openssl "${sign_args[@]}" -extfile <(ssl_selfsigned_extfile "${@}")
        else
            cmd openssl "${sign_args[@]}"
        fi

        cmd chown "${key_owner}:${key_group}" "${key_path}"
        cmd chmod 0400 "${key_path}"
        cmd chown root:root "${cert_path}"
        cmd chmod 644 "${cert_path}"
    fi
}
