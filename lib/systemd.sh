#!/usr/bin/env bash

# MIT license
# Copyright 2021 Sergej Alikov <sergej.alikov@gmail.com>


systemd_is_active () {
    cmd_is_available systemctl && systemctl --quiet is-active -- '-.mount'
}


# TODO: Deprecate this once AUT-61 is done
systemd_reload_daemon () {
    systemctl daemon-reload
}


systemd_quoted () {
    declare arg
    declare -a result=()

    for arg in "$@"; do
        # shellcheck disable=SC1003
        result+=("\"$(translated "$arg" '\' '\\' '"' '\"' '%' '%%' '$' '$$')\"")
    done

    printf '%s\n' "${result[*]}"
}


systemd_ensure_unit_active () {
    declare unit="$1"
    declare start_on_boot="$2"

    if is_true "$start_on_boot"; then
        systemctl enable "$unit"
    else
        systemctl disable "$unit"
    fi

    if ! systemctl -q is-active "$unit"; then
        log_debug "Starting ${unit}"
        systemctl start "$unit"
    fi
}


systemd_set_up_service () {
    declare name="$1"
    declare service_unit_file="$2"
    declare start_on_boot="$3"

    to_file /etc/systemd/system/"${name}.service" systemd_reload_daemon \
            < "$service_unit_file"

    systemd_ensure_unit_active "${name}.service" "$start_on_boot"
}


systemd_set_up_timer_service () {
    declare name="$1"
    declare service_unit_file="$2"
    declare timer_unit_file="$3"
    declare start_on_boot="$4"

    # There is a bug in Bash 4.2 which causes process substitution
    # FIFOs to be invalidated by pipelines. Current implementation
    # of to_file() triggers this bug, as it makes use of pipelines.
    # The bug was fixed in Bash 4.3
    if ! bash_minor_version_is_higher_than 4 2; then
        if [[ -p "$service_unit_file" || -p "$timer_unit_file" ]]; then
            throw "Using pipes with systemd_set_up_timer_service() is not supported with Bash versions < 4.3"
        fi
    fi

    to_file /etc/systemd/system/"${name}.service" systemd_reload_daemon \
            <"$service_unit_file"

    to_file /etc/systemd/system/"${name}.timer" systemd_reload_daemon \
            <"$timer_unit_file"

    systemd_ensure_unit_active "${name}.timer" "$start_on_boot"
}


systemd_timer2 () {
    declare description="$1"
    declare schedule="$2"

    cat <<EOF
[Unit]
Description=${description}

[Timer]
OnCalendar=${schedule}

[Install]
WantedBy=timers.target
EOF
}


systemd_oneshot () {
    declare description="$1"
    [[ "$2" == 'exec_start' ]] || declare -n exec_start="$2"

    if [[ -n "${3:-}" ]]; then
        [[ "$3" == 'depends_on' ]] || declare -n depends_on="$3"
    else
        declare -a depends_on=()
    fi

    cat <<EOF
[Unit]
Description=${description}
EOF
    if [[ "${#depends_on[@]}" -gt 0 ]]; then
        cat <<EOF
Requires=${depends_on[@]}
After=${depends_on[@]}
EOF
    fi

    declare quoted_exec_start
    quoted_exec_start=$(systemd_quoted "${exec_start[@]}")

    cat <<EOF

[Service]
User=root
Type=oneshot
ExecStart=${quoted_exec_start}
EOF
}


systemd_mount_unit () {
    declare what="$1"
    declare where="$2"
    declare filesystem="$3"
    declare options="$4"
    declare description="$5"

    # https://www.freedesktop.org/software/systemd/man/systemd.mount.html#Options
    cat <<EOF
[Unit]
Description=${description}

[Mount]
What=${what}
Where=${where}
Type=${filesystem}
Options=${options}

[Install]
WantedBy=multi-user.target
EOF
}


systemd_set_up_mount () {
    declare dev="$1"
    declare mountpoint="$2"
    declare filesystem="$3"
    declare options="$4"
    declare description="$5"
    declare start_on_boot="${6:-FALSE}"

    declare mount_unit
    mount_unit=$(systemd-escape --path "$mountpoint")

    log_info "Mounting ${mountpoint}"

    mkdir -p "$mountpoint"

    to_file "/etc/systemd/system/${mount_unit}.mount" \
            systemd_reload_daemon \
            < <(systemd_mount_unit "$dev" "$mountpoint" "$filesystem" "$options" "$description")

    systemd_ensure_unit_active "${mount_unit}.mount" "$start_on_boot"
}
