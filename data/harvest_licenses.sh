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
cd "$script_source"
licenses_dir='data/choosealicense.com_licenses'
lockfile='data/licenses.lock'

# Will exit successfully (exit code 0) if the lockfile matches the latest commit or exit with an
# error (exit code 1) if it it's out of date (meaning that the license list _could_ have changed).
if [ "${1:-''}" = '-c' ] || [ "${1:-''}" = '--check' ]; then
    check='true'
else
    check='false'
fi

current_commit_hash="$(head -n1 < "$lockfile")"
current_commit_date="$(tail -n1 < "$lockfile")"

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

    LC_TIME='POSIX' TZ=':Etc/GMT' \
        date --date "$iso_8601_date" \
        '+%a, %d %b %Y %H:%M:%S %Z'
}

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
        set -- '--location' "$@"
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

cat << EOF > "$lockfile"
$latest_commit_hash
$latest_commit_date
EOF

if [ "$current_commit_hash" = "$latest_commit_hash" ]; then
    echo 'Up to date!'
    exit 0
fi

echo "Downloading license files if the directory has changed since $current_commit_date"

gh_api '/repos/github/choosealicense.com/contents/_licenses' \
    --header 'Accept: application/vnd.github.raw+json' \
    --header "If-Modified-Since: $(iso_8601_to_http_date "$current_commit_date")" \
    | sed 's/"download_url": \?"\([^"]\+\)"/\n\x0\1\n/g' \
    | grep --perl-regexp --text '^\x0' \
    | tr --delete '\0' \
    | xargs curl --location --output-dir "$licenses_dir" --remote-name-all
