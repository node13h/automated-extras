#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


influx_database_exists () {
    local database="${1}"

    influx -format json -execute 'SHOW DATABASES' | jq  -r 'try .results[0].series[0].values[][] catch empty' | grep "^${database}$" &>/dev/null
}

influx_user_exists () {
    local user="${1}"

    influx -format json -execute 'SHOW USERS' | jq  -r 'try .results[0].series[0].values[][0] catch empty' | grep "^${user}$" &>/dev/null
}

influx_create_db () {
    local db="${1}"
    local owner="${2:-}"
    local raw_retention="${3:-4w}"
    local rollup_retention="${4:-52w}"

    msg "Creating \"${db}\" InfluxDB DB"
    cmd influx -execute "CREATE DATABASE ${db}"

    [[ -z "${owner}" ]] || cmd influx -execute "GRANT ALL ON \"${db}\" TO \"${owner}\""

    cmd influx -database "${db}" -execute "CREATE RETENTION POLICY \"raw\" ON \"${db}\" DURATION ${raw_retention} REPLICATION 1 DEFAULT"
    cmd influx -database "${db}" -execute "CREATE RETENTION POLICY \"rollup\" ON \"${db}\" DURATION ${rollup_retention} REPLICATION 1"
    cmd influx -database "${db}" -execute "CREATE CONTINUOUS QUERY \"${db}_rollup_cq\" ON \"${db}\" BEGIN SELECT mean(*) INTO \"${db}\".\"rollup\".:MEASUREMENT FROM /.*/ GROUP BY time(30m),* END"
}

influx_create_user () {
    local user="${1}"
    local password="${2}"
    local level="${3:-user}"

    local -a q

    q=("CREATE USER \"${user}\" WITH PASSWORD '${password}'")

    if [[ "${level}" = 'admin' ]]; then
        q+=('WITH ALL PRIVILEGES')
    fi

    cmd influx -execute "${q[*]}"
}
