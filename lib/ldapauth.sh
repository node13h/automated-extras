#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


ldap_get_ssh_key () {
    cat <<"EOF"
#!/bin/sh
ldapsearch -x -ZZ '(&(objectClass=posixAccount)(uid='"$1"'))' 'sshPublicKey' | sed -n '/^ /{H;d};/sshPublicKey:/x;$g;s/\n *//g;s/sshPublicKey: //gp'
EOF
}

setup_sssd_ldap_auth () {
    local server_url="${1}"
    local base_dn="${2}"
    local cacert="${3}"

    # Package oddjob-mkhomedir must be installed before running authconfig
    # Or else home directory creation will fail, because authconfig will
    # add pam_mkhomedir instead of pam_oddjob_mkhomedir in
    # /etc/pam.d/system-auth

    packages_ensure present oddjob-mkhomedir sssd

    cmd systemctl enable oddjobd
    systemctl -q is-active oddjobd || cmd systemctl start oddjobd

    cmd mkdir -p /etc/openldap/cacerts
    cmd certutil -d /etc/openldap/cacerts -A -n "CA for LDAP" -t CT,, -a -i "${cacert}"

    cmd authconfig \
        --enablesssd \
        --enablesssdauth \
        --enablelocauthorize \
        --enableldap \
        --enableldapauth \
        --ldapserver="${server_url}" \
        --enableldaptls \
        --ldapbasedn="${base_dn}" \
        --enablemkhomedir \
        --enablecachecreds \
        --update
}

setup_ldap_authorized_keys () {
    msg "Setting up the automatic retrieval of the SSH keys from the LDAP"

    packages_ensure present openldap-clients

    ldap_get_ssh_key | to_file /etc/ssh/ldap-get-ssh-key.sh
    cmd chmod +x /etc/ssh/ldap-get-ssh-key.sh

    cmd rm -f /etc/ssh/sshd_config.augsave

    cmd augtool -b set /files/etc/ssh/sshd_config/AuthorizedKeysCommand /etc/ssh/ldap-get-ssh-key.sh
    cmd augtool -b set /files/etc/ssh/sshd_config/AuthorizedKeysCommandUser root

    ! [[ -e /etc/ssh/sshd_config.augsave ]] || cmd systemctl restart sshd
}
