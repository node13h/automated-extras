#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


bacula_fd_conf () {
    local fd_name="${1}"
    local dir_name="${2}"
    local password="${3}"
    local ssl_bundle_path="${4}"
    local ssl_master_key="${5}"
    local listen_address="${6:-127.0.0.1}"

    cat <<EOF
Director {
  Name = "${dir_name}"
  Password = "${password}"
}

FileDaemon {
  Name = ${fd_name}
  FDport = 9102
  WorkingDirectory = /var/spool/bacula
  Pid Directory = /var/run
  Maximum Concurrent Jobs = 20
  FDAddress = ${listen_address}

  PKI Signatures = Yes
  PKI Encryption = Yes
  PKI Keypair = "${ssl_bundle_path}"
  PKI Master Key = "${ssl_master_key}"

}

# Send all messages except skipped files back to Director
Messages {
  Name = Standard
  director = "${dir_name}" = all, !skipped, !restored
}
EOF
}
