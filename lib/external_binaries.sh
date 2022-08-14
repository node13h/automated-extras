#!/usr/bin/env bash


declare -A EXTERNAL_BINARIES_CHECKSUMS=()
declare -A EXTERNAL_BINARIES_URLS=()


# TODO: Documentation
external_binaries_verify_sha256 () {
    declare file_path="$1"
    declare sha256="$2"

    log_debug "Verifying checksum for ${file_path}"
    printf '%s *%s\n' "$sha256" "$file_path" | sha256sum -c --status -

}


# TODO: Documentation
external_binaries_download () {
    declare dest_dir="$1"
    shift 1

    declare filename path checksum url
    for filename in "$@"; do
        path="${dest_dir}/${filename}"
        checksum="${EXTERNAL_BINARIES_CHECKSUMS[$filename]}"
        url="${EXTERNAL_BINARIES_URLS[$filename]}"

        if ! external_binaries_verify_sha256 "$path" "$checksum"; then
            rm -f -- "$path"
            log_debug "Downloading ${url} as ${path}"
            curl -fL "$url" -o "$path"

            # Also verify after downloading
            external_binaries_verify_sha256 "$path" "$checksum"
        fi
    done
}
