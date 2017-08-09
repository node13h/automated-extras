#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


do_as_postgres () {
    (
        # Avoid "permission denied" errors due to cwd in other user's home
        cd / || return 1
        sudo -u postgres "${@}"
    )
}


pg_user_exists () {
    [[ -n "$(do_as_postgres psql -Atq -c "\\du ${1}")" ]]
}

pg_database_exists () {
    [[ -n "$(do_as_postgres psql -Atq -c "\\l ${1}")" ]]
}

pg_createuser () {
    local username="${1}"
    local password="${2}"

    msg "Creating ${username} PostgreSQL user"

    cmd do_as_postgres createuser "${@:3}" "${username}"
    cmd do_as_postgres psql -c "ALTER USER ${username} WITH PASSWORD '${password}';"
}

pg_createdb () {
    local db="${1}"
    local owner="${2}"

    cmd do_as_postgres createdb -O "${owner}" "${db}"
}

pg_enable_extension () {
    local database="${1}"
    local extension="${2}"

    msg "Enabling ${extension} PostgreSQL extension"

    cmd do_as_postgres psql -c "CREATE EXTENSION IF NOT EXISTS \"${extension}\";" "${database}"
}

pgdg_libdir () {
    local pg_version="${1}"

    case "${FACT_OS_FAMILY}" in
        'RedHat')
            echo "/usr/pgsql-${pg_version}"
            ;;
        *)
            echo "/usr/lib/postgresql/${pg_version}"
            ;;
    esac
}

pgdg_default_datadir () {
    local pg_version="${1}"

    case "${FACT_OS_FAMILY}" in
        'RedHat')
            echo "/var/lib/pgsql/${pg_version}/data"
            ;;
        *)
            echo "/var/lib/postgresql/${pg_version}/main"
            ;;
    esac
}

pgdg_label1 () {
    case "${FACT_OS_NAME}" in
        'CentOS'|'RHEL')
            echo 'redhat'
            ;;
        'Fedora')
            echo 'fedora'
            ;;
    esac
}

pgdg_label2 () {
    case "${FACT_OS_NAME}" in
        'CentOS'|'RHEL')
            echo 'rhel'
            ;;
        'Fedora')
            echo 'fedora'
            ;;
    esac
}

pgdg_gpg_key_name () {
    local pg_version="${1}"

    printf 'RPM-GPG-KEY-PGDG-%s\n' "${pg_version/./}"
}

pgdg_repo_name () {
    local pg_version="${1}"

    printf 'pgdg-%s-%s\n' "${pg_version/./}" "$(pgdg_label1)"
}

pgdg_package_name_base () {
    local pg_version="${1}"

    printf 'postgresql%s\n' "${pg_version/./}"
}

pgdg_gpg_key () {
    local pg_version="${1}"

    curl -s "https://download.postgresql.org/pub/repos/yum/$(pgdg_gpg_key_name "${pg_version}")"
}

el_pgdg_repo () {
    local pg_version="${1}"
    local gpg_key_path="${2}"

    cat <<EOF
[$(pgdg_repo_name "${pg_version}")]
name=PostgreSQL ${pg_version} \$releasever - \$basearch
baseurl=https://download.postgresql.org/pub/repos/yum/${pg_version}/$(pgdg_label1)/$(pgdg_label2)-\$releasever-\$basearch
enabled=1
gpgcheck=1
gpgkey=file://${gpg_key_path}

[$(pgdg_repo_name "${pg_version}")-source]
name=PostgreSQL ${pg_version} \$releasever - \$basearch - Source
failovermethod=priority
baseurl=https://download.postgresql.org/pub/repos/yum/srpms/${pg_version}/$(pgdg_label1)/$(pgdg_label2)-\$releasever-\$basearch
enabled=0
gpgcheck=1
gpgkey=file://${gpg_key_path}

[$(pgdg_repo_name "${pg_version}")-updates-testing]
name=PostgreSQL ${pg_version} \$releasever - \$basearch
baseurl=https://download.postgresql.org/pub/repos/yum/testing/${pg_version}/$(pgdg_label1)/$(pgdg_label2)-\$releasever-\$basearch
enabled=0
gpgcheck=1
gpgkey=file://${gpg_key_path}

[$(pgdg_repo_name "${pg_version}")-source-updates-testing]
name=PostgreSQL ${pg_version} \$releasever - \$basearch - Source
failovermethod=priority
baseurl=https://download.postgresql.org/pub/repos/yum/srpms/testing/${pg_version}/$(pgdg_label1)/$(pgdg_label2)-\$releasever-\$basearch
enabled=0
gpgcheck=1
gpgkey=file://${gpg_key_path}
EOF
}

pg_ensure_datadir_initialized () {
    local pg_version="${1}"
    local datadir_path="${2:-$(pgdg_default_datadir "${pg_version}")}"

    if [[ "$(find "${datadir_path}" -mindepth 1 -printf '.' | wc -c)" -eq 0 ]]; then
        msg "Initializing PostgreSQL data directory at ${datadir_path}"
        do_as_postgres "$(pgdg_libdir "${pg_version}")/bin/initdb" "${datadir_path}"
    fi
}

default_pg_hba () {
    cat <<EOF
# DO NOT DISABLE!
# If you change this first entry you will need to make sure that the
# database superuser can access the database using some other method.
# NoninteractIve access to all databases is required during automatic
# maintenance (custom daily cronjobs, replication, and similar tasks).
#
# Database administrative login by Unix domain socket
local   all             postgres                                peer

# Base backups
local   replication     postgres                                peer

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            md5
# IPv6 local connections:
host    all             all             ::1/128                 md5

EOF
}

pg_hba_host () {
    local database="${1}"
    local username="${2}"
    local address="${3}"

    printf 'host %s %s %s md5\n' "${database}" "${username}" "${address}"
}

postgresql_conf () {
    local ssl_key_path="${1}"
    local ssl_cert_path="${2}"
    local max_connections="${3}"
    local shared_buffers="${4}"
    local effective_cache_size="${5}"
    local work_mem="${6}"
    local backups_dir="${7}"

    cat <<EOF
listen_addresses = '*'
max_connections = ${max_connections}

shared_buffers = ${shared_buffers}
effective_cache_size = ${effective_cache_size}
work_mem = ${work_mem}
dynamic_shared_memory_type = posix

log_destination = 'stderr'
logging_collector = on
log_directory = 'pg_log'
log_filename = 'postgresql-%a.log'
log_truncate_on_rotation = on
log_rotation_age = 1d
log_rotation_size = 0
log_line_prefix = '< %m > '

datestyle = 'iso, mdy'
lc_messages = 'en_US.utf8'
lc_monetary = 'en_US.utf8'
lc_numeric = 'en_US.utf8'
lc_time = 'en_US.utf8'
default_text_search_config = 'pg_catalog.english'

ssl = true
ssl_cert_file = '${ssl_cert_path}'
ssl_key_file = '${ssl_key_path}'

wal_level = hot_standby
archive_mode = on
archive_command = 'test ! -f "${backups_dir}/pgarchive/%f" && gzip < "%p" > "${backups_dir}/pgarchive/%f"'
max_wal_senders = '3'
EOF
}

pg_basebackup_crond_main () {
    local pg_version="${1}"
    local backups_dir="${2}"

    cat <<EOF
MAILTO=root

0 6 * * *     root /opt/pgba/pg-basebackup.py --pg-archivecleanup "$(pgdg_libdir "${pg_version}")/bin/pg_archivecleanup" --pgbase-path "${backups_dir}/pgbase" --pgarchive-path "${backups_dir}/pgarchive" >/dev/null 2>&1
EOF
}

setup_postgresql_backups () {
    local pg_version="${1}"
    local backups_dir="${2}"

    [[ -d /opt/pgba ]] || git clone https://github.com/node13h/pgba.git /opt/pgba

    mkdir -p "${backups_dir}/pgarchive"
    mkdir -p "${backups_dir}/pgbase"
    chown postgres:postgres "${backups_dir}/pgarchive" "${backups_dir}/pgbase"

    pg_basebackup_crond_main "${pg_version}" "${backups_dir}" | to_file "/etc/cron.d/pg-basebackup-main"
}
