#!/usr/bin/env bash

# MIT license
# Copyright 2022 Sergej Alikov <sergej.alikov@gmail.com>

## @file
## @author Sergej Alikov <sergej.alikov@gmail.com>
## @copyright MIT License
## @brief cfssl helper functions


## @fn cfssl_initca ()
## @brief Generate a CA cert/key pair and output as JSON
## @details "cert" JSON key will contain the certificate body,
## "key" JSON key will contain the certificate key
## @param ca_name CN for the CA certificate
## @param key_size RSA key size
## @param expiry exipiration time; see https://pkg.go.dev/time#ParseDuration
## for supported duration formats
##
## Example:
##
## Generate a CA and store the cert/key in a pass password store
## @code{.sh}
## (
##     source <(cfssl_initca 'Example CA' 2048 '43800h' | cfssl_toenv cfssl_ca_)
##     pass insert --multiline 'CA/Example CA/cacert' <<< "$cfssl_ca_cert"
##     pass insert --multiline 'CA/Example CA/cacert-key' <<< "$cfssl_ca_key"
## )
## @endcode
cfssl_initca () {
    declare ca_name="$1"
    declare -i key_size="$2"
    declare expiry="$3"

    jq -ne \
       --arg ca_name "$ca_name" \
       --arg expiry "$expiry" \
       --argjson key_size "$key_size" \
       '{key: {algo: "rsa", size: $key_size}, CN: $ca_name, CA: {expiry: $expiry}}' \
        | cfssl gencert -initca -
}


## @fn cfssl_gencert ()
## @brief Generate a cert/key pair and output as JSON
## @details "cert" JSON key will contain the certificate body,
## "key" JSON key will contain the certificate key
## @param cn CN for the certificate
## @param ca_cert CA certificate reference; can be either
## file:path/to/cert or env:var_name
## @param ca_cert_key CA key reference; can be either
## file:path/to/key or env:var_name
## @param profile signing profile; supported values are: client-server, server,
## client, signing
## @param key_size RSA key size
## @param expiry exipiration time; see https://pkg.go.dev/time#ParseDuration
## for supported duration formats
## @param san SAN to include in the certificate; may be specified multiple times
##
## Example:
##
## Generate a cert/key with the 'host.example.com' CN and host.example.com,
## alias.examle.com, and 192.0.2.1 SANs.
## Use the CA cert/key from env vars (see the example from cfssl_initca())
## @code{.sh}
## (
##     export cfssl_ca_cert
##     export cfssl_ca_cert_key
##
##     source <(cfssl_gencert 'host.example.com' \
##                            'env:cfssl_ca_cert' \
##                            'env:cfssl_ca_cert_key' \
##                            client-server \
##                            2048 \
##                            "8760h" \
##                            'host.example.com' 'alias.examle.com' '192.0.2.1' \
##                  | cfssl_toenv cfssl_)
##
##     pass insert --multiline 'CA/Example CA/server.example.com/client-server-cert' <<< "$cfssl_cert"
##     pass insert --multiline 'CA/Example CA/server.example.com/client-server-cert-key' <<< "$cfssl_key"
## )
## @endcode
##
## Same, but the CA cert/key is pulled from a pass password store
## @code{.sh}
## (
##     source <(cfssl_gencert 'host.example.com' \
##                            'file:'<(pass 'CA/Example CA/cacert') \
##                            'file:'<(pass 'CA/Example CA/cacert-key') \
##                            client-server \
##                            2048 \
##                            "8760h" \
##                            'host.example.com' 'alias.examle.com' '192.0.2.1' \
##                  | cfssl_toenv cfssl_)
##     pass insert --multiline 'CA/Example CA/server.example.com/client-server-cert' <<< "$cfssl_cert"
##     pass insert --multiline 'CA/Example CA/server.example.com/client-server-cert-key' <<< "$cfssl_key"
## )
## @endcode
cfssl_gencert () {
    declare cn="$1"
    declare ca_cert="$2"
    declare ca_cert_key="$3"
    declare profile="$4"
    declare -i key_size="$5"
    declare expiry="$6"

    shift 6

    declare -a usages=()

    case "$profile" in
        client-server)
            usages=('signing' 'key encipherment' 'server auth' 'client auth')
            ;;
        server)
            usages=('signing' 'key encipherment' 'server auth')
            ;;
        client)
            usages=('signing' 'key encipherment' 'client auth')
            ;;
        signing)
            usages=('signing' 'key encipherment')
            ;;
    esac

    jq -ne \
       --arg cn "$cn" \
       --argjson key_size "$key_size" \
       '{hosts: $ARGS.positional, key: {algo: "rsa", size: $key_size}, CN: $cn}' \
       --args "$@" \
        | cfssl gencert \
                -ca="$ca_cert" \
                -ca-key="$ca_cert_key" \
                -config=<(jq -ne \
                             --arg expiry "$expiry" \
                             '{signing: {default: {usages: $ARGS.positional, expiry: $expiry}}}' \
                             --args "${usages[@]}") \
                -

}


## @fn cfssl_toenv ()
## @brief Transform JSON cfssl output to shell environment variable declarations
## @details Feed the output of cfssl_initca() or cfssl_gencert() into this
## function. The transformed can be sourced.
## @param prefix prefix to use for the cert and key variable names
##
## Example:
##
## @code{.sh}
## source <(cfssl_initca 'Example CA' 2048 '43800h' | cfssl_toenv cfssl_ca_)
## printf '%s\n "$cfssl_ca_cert" "$cfssl_ca_key"
## @endcode
cfssl_toenv () {
    declare prefix="$1"

    jq -re --arg prefix "$prefix" 'to_entries|.[]|"\($prefix + .key)=\(.value|@sh)"'
}
