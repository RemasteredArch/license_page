#! /usr/bin/env bash

# SPDX-License-Identifier: MPL-2.0
#
# Copyright © 2025 RemasteredArch
#
# This Source Code Form is subject to the terms of the Mozilla Public License, version 2.0. If a
# copy of the Mozilla Public License was not distributed with this file, You can obtain one at
# <https://mozilla.org/MPL/2.0/>.

set -euo pipefail # Quit upon any error or attempt to access unset variables.

script_source="$(dirname "$(realpath "$0")")"
cd "$script_source/.." # Root of the repository.
licenses_dir='data/choosealicense.com_licenses'
lockfile='data/licenses.lock'
rust_license_list_file='data/choosealicense.com_licenses.rs'

# Will exit successfully (exit code 0) if the lockfile matches the latest commit or exit with an
# error (exit code 1) if it it's out of date (meaning that the license list _could_ have changed).
if [ "${1:-''}" = '-c' ] || [ "${1:-''}" = '--check' ]; then
    check='true'
else
    check='false'
fi

current_commit_hash="$(head -n1 < "$lockfile")"
current_commit_date="$(tail -n1 < "$lockfile")"

force_download='false'
if [ "$current_commit_hash" = '' ] \
    || [ "${1:-''}" = '-f' ] \
    || [ "${1:-''}" = '--force-download' ]; then
    force_download='true'
fi

echo '' > "$lockfile"

# Detect if a program or alias exists
has() {
    [ "$(type "$1" 2> /dev/null)" ]
}

# Converts an ISO-8601 date to a valid HTTP date.
#
# E.g., `2025-04-15T19:07:25Z` -> `Tue, 15 Apr 2025 19:07:25 GMT`.
#
# <https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Date>
iso_8601_to_http_date() {
    local iso_8601_date="$1"

    # This might have weird behavior if `LC_ALL` is set.
    LC_TIME='POSIX' TZ=':Etc/GMT' \
        date --date "$iso_8601_date" \
        '+%a, %d %b %Y %H:%M:%S %Z'
}

# Make a request to the GitHub REST API. Prefers using the GitHub CLI, but will fallback to `curl`
# if `gh` isn't present. If `curl` is being used, the HTTP response will _always_ be printed to
# stderr.
gh_api() {
    local endpoint="$1"
    shift # Drop the first argument.

    # Prepend version header.
    set -- '--header' 'X-GitHub-Api-Version: 2022-11-28' "$@"

    # Prefer using the GitHub CLI so that requests can be authenticated without messing with tokens
    # manually.
    local api_client
    if has 'gh'; then
        api_client='gh'
        set -- 'api' "$@"
    else
        api_client='curl'
        set -- '--fail' '--silent' '--show-error' '--location' \
            '--write-out' '%{stderr}curl: HTTP %{http_code}' \
            "$@"
        endpoint="https://api.github.com$endpoint"
    fi

    "$api_client" "$@" "$endpoint"
}

echo "Currently locked at commit: $current_commit_hash ($current_commit_date)"

latest_commit_json="$(
    gh_api '/repos/github/choosealicense.com/commits?per_page=1' \
        --header 'Accept: application/vnd.github+json'
)"
latest_commit_hash="$(
    echo "$latest_commit_json" \
        | grep --only-matching '"sha": \?"[^"]*"' \
        | head -n1 \
        | sed 's/^"sha": \?"\(.\+\)"$/\1/'
)"
latest_commit_date="$(
    echo "$latest_commit_json" \
        | grep --only-matching '"date": \?"[^"]*"' \
        | head -n1 \
        | sed 's/^"date": \?"\(.\+\)"$/\1/'
)"

echo "Latest commit: $latest_commit_hash ($latest_commit_date)"

# Exits successfully (exit code 0) if the lockfile matches the latest commit or exits with an error
# (exit code 1) if it it's out of date (meaning that the license list _could_ have changed).
if [ "$check" = 'true' ]; then
    if [ "$current_commit_hash" = "$latest_commit_hash" ]; then
        exit 0
    else
        exit 1
    fi
fi

if [ "$current_commit_hash" = "$latest_commit_hash" ] && [ "$force_download" = 'false' ]; then
    echo 'Up to date!'

    cat << EOF > "$lockfile"
$latest_commit_hash
$latest_commit_date
EOF
    exit 0
fi

echo 'Fetching license file list'

# For this request, when we get HTTP `304 Not Modified`, we want to skip downloading the license
# files. Besides trying to distinguish other errors from a 304 response, we also have to distinguish
# based on client --- the GitHub CLI treats HTTP `304 Not Modified` as an error, `curl` doesn't.

skip_download='false'
stderr="$(mktemp)"
# Given no current commit date, default to the year 2000.
#
# `iso_8601_to_http_date`, if given an empty string, will return the current date, which would
# reasonably guarantee an HTTP 304 response, so we need to manually ensure we set it to some
# arbitrarily old date (in this case, the year 2000) to effectively disable 304 responses.
if [ "$current_commit_date" = '' ]; then
    since='2000-01-01'
else
    since="$current_commit_date"
fi

# Capture stdout into `response` and stderr into a temporary file. There might ways to do something
# similar more efficiently with file descriptors, but this is much simpler.
if response="$(
    gh_api '/repos/github/choosealicense.com/contents/_licenses' \
        --header 'Accept: application/vnd.github.raw+json' \
        --header "If-Modified-Since: $(iso_8601_to_http_date "$since")" \
        2> "$stderr"
)"; then
    if [ "$(cat "$stderr")" = 'curl: HTTP 304' ] && [ "$force_download" = 'false' ]; then
        skip_download='true'
    fi
else
    exit_code="$?"

    if [ "$(cat "$stderr")" = 'gh: HTTP 304' ] && [ "$force_download" = 'false' ]; then
        skip_download='true'
    else
        cat "$stderr" 1>&2
        exit $exit_code
    fi
fi

if [ "$skip_download" = 'true' ]; then
    echo 'License files unchanged, skipping download'
else
    echo 'Downloading license files'

    download_urls="$(
        echo "$response" \
            | sed 's/"download_url": \?"\([^"]\+\)"/\n\x0\1\n/g' \
            | grep --perl-regexp --text '^\x0' \
            | tr --delete '\0'
    )"
    echo "$download_urls" | xargs curl --location --output-dir "$licenses_dir" --remote-name-all

    # shellcheck disable=SC2016
    echo 'Exporting license list to `data/`'"$rust_license_list_file"

    # shellcheck disable=SC2016
    echo '// This file was @generated by `harvest_licenses.sh`. Do not edit!' \
        > "$rust_license_list_file"
    echo '[' >> "$rust_license_list_file"

    old_lc_all="${LC_ALL:-UNSET}"
    # AFAIK, setting `LC_ALL=C` will cause GNU `sort` (and hopefully the glob expansion too) to compare
    # on byte values alone. I hope I'm right, that could be some fun wrong behavior if it doesn't.
    export LC_ALL='C'

    echo 'Processing files...'
    for file in data/choosealicense.com_licenses/*; do
        if ! echo "$download_urls" | grep --quiet "$(basename "$file")$"; then
            echo '  Removing `'"$file"'` (not in the download list)'
            rm "$file"
            continue
        fi

        echo "- $file"

        # Strip front matter from file.
        #
        # Onliner from <https://stackoverflow.com/a/29292490> by
        # [`don_crissti`](https://stackoverflow.com/users/1601027/don-crissti), licensed
        # [`CC-BY-SA 4.0`](https://creativecommons.org/licenses/by-sa/4.0/).
        sed --in-place '1{/^---$/!q;};1,/^---$/d' "$file"
        # Strip leading blank line.
        sed --in-place '1,/^$/d' "$file"

        echo \
            "    (\"$(basename "$file" '.txt')\", include_str!(\"../data/choosealicense.com_licenses/$(basename "$file")\"))," \
            >> "$rust_license_list_file"
    done

    if [ "$old_lc_all" = 'UNSET' ]; then
        export -n LC_ALL
    else
        export LC_ALL="$old_lc_all"
    fi

    echo ']' >> "$rust_license_list_file"
fi

cat << EOF > "$lockfile"
$latest_commit_hash
$latest_commit_date
EOF
