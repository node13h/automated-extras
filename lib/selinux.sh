#!/usr/bin/env bash

# MIT license
# Copyright 2018 Sergej Alikov <sergej.alikov@gmail.com>


fcontext_file_spec_exists () {
    declare file_spec="$1"
    declare spec rest

    while read -r spec rest; do
        if [[ "$spec" = "$file_spec" ]]; then
            return 0
        fi
    done < <(semanage fcontext -l -C -n)

    return 1
}

fcontext_ensure () {
    local type="$1"
    local file_spec="$2"

    if fcontext_file_spec_exists "$file_spec"; then
        cmd semanage fcontext -m -t "$type" "$file_spec"
    else
        cmd semanage fcontext -a -t "$type" "$file_spec"
    fi
}
