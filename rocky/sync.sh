# vim: syntax=sh ts=4 shiftwidth=4 expandtab
#!/usr/bin/env bash

#############################################################
#                                                           #
# Creates a local mirror for Rocky Linux releases           #
#                                                           #
# Environment variables:                                    #
#   BWLIMIT        : Download rate limit for curl           #
#   DRYRUN         : If equal to "1" then perform a dry run #
#   MIRROR_URL     : rsync URL to mirror from               #
#   OUTPUT_DIR     : Output directory                       #
#                                                           #
#############################################################

readonly DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly LOCKFILE="${DIR}/mirror.lock"

readonly BWLIMIT="${BWLIMIT:-256K}"
readonly DRYRUN="${DRYRUN:-0}"
readonly MIRROR_URL="${MIRROR_URL:-rsync://ord.mirror.rackspace.com/rocky}"
readonly OUTPUT_DIR="${OUTPUT_DIR:-/var/www/html/mirror/rocky}"

readonly REPOKEY="RPM-GPG-KEY-rockyofficial"
readonly RELEASES=( "9.0" "9.1" )

source "${DIR}/../util.sh"

# Prevent more than one instance of this script running
if test -f "$LOCKFILE" ; then
    printf "ERROR: Script is already running! Exiting\n" 2>&1
    exit 1
fi

function onerror () {
	log_info "Caught SIGINT...removing lockfile and exiting"
	
	[[ -f "$LOCKFILE" ]] && rm -f "$LOCKFILE"

	exit 1
}

function sync_release () {
    local release="$1"
    local sync_url="${MIRROR_URL}/${release}/"
    local sync_dir="${OUTPUT_DIR}/${release}"
    local exclude_file="${DIR}/excludes/${release}.txt"
    local rsync_args="--archive --verbose --sparse --hard-links --partial --progress --delete --bwlimit=${BWLIMIT} --exclude-from=${exclude_file}"

    [[ "$DRYRUN" == "1" ]] && rsync_args+=" --dry-run"

    log_info "Syncing local mirror for Rocky Linux ${release} ..."

    if ! test -f "$exclude_file" ; then
        log_error "Cannot find exclude file ${blue}${exclude_file}${red}, skipping sync for release ..."
        return 1
    fi

    test -d "$sync_dir" || mkdir --parent "$sync_dir"

    rsync $rsync_args "$sync_url" "$sync_dir/" --delete-excluded

    log_info "Sync complete!"
}

trap "onerror" SIGINT SIGTERM EXIT

touch "$LOCKFILE"

set -m

for RELEASE in "${RELEASES[@]}"; do
    sync_release $RELEASE
done

log_info "Finished!"

rm -f "$LOCKFILE"
