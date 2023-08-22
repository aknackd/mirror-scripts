# vim: syntax=sh ts=4 shiftwidth=4 expandtab
#!/usr/bin/env bash

#############################################################
#                                                           #
# Creates a local mirror for EPEL packages                  #
#                                                           #
# Environment variables:                                    #
#   BWLIMIT        : Download rate limit for curl           #
#   DRYRUN         : If equal to "1" then perform a dry run #
#   MIRROR_URL     : rsync URL to mirror from               #
#   OUTPUT_DIR     : Output directory                       #
#                                                           #
#############################################################

readonly DIR="$(dirname "${BASH_SOURCE[0]}")"
readonly LOCKFILE="${DIR}/lock"

readonly BWLIMIT="${BWLIMIT:-256K}"
readonly DRYRUN="${DRYRUN:-0}"
readonly MIRROR_URL="${MIRROR_URL:-rsync://ord.mirror.rackspace.com/epel}"
readonly OUTPUT_DIR="${OUTPUT_DIR:-/var/www/html/mirror/epel}"

readonly REPOKEY="RPM-GPG-KEY-EPEL"
readonly RELEASES=( "9" )

source "${DIR}/../util.sh"

# Prevent more than one instance of this script running
if test -f "$LOCKFILE" ; then
    printf "ERROR: Script is already running! Exiting\n" 2>&1
    exit 1
fi

# https://stackoverflow.com/a/17841619
function implode { local IFS="$1"; shift; echo "$*"; }

function onerror () {
	log_info "Caught SIGINT...removing lockfile and exiting"
	
	[[ -f "$LOCKFILE" ]] && rm -f "$LOCKFILE"

	exit 1
}

function sync_gpg_key () {
    local release="$1"
    local sync_dir="$OUTPUT_DIR"

    local sync_filename="${REPOKEY}"
    [[ "$release" != "" ]] && sync_filename+="-${release}"

    [[ "$release" != "" ]] \
        && log_info "Syncing GPG key for EPEL release ${release} ..." \
        || log_info "Syncing main GPG key for EPEL ..."

    local sync_url="${MIRROR_URL}/${sync_filename}"
    local rsync_args="--archive --verbose --sparse --hard-links --partial --progress --delete --bwlimit=${BWLIMIT}"

    [[ "$DRYRUN" == "1" ]] && rsync_args+=" --dry-run"

    test -d "$sync_dir" || mkdir --parent "$sync_dir"

    rsync $rsync_args "$sync_url" "$sync_dir/${sync_filename}"

    log_info "Sync complete!"
}

function sync_release () {
    local release="$1"
    local sync_url="${MIRROR_URL}/${release}/"
    local sync_dir="${OUTPUT_DIR}/${release}"
    local exclude_file="${DIR}/excludes/${release}.txt"
    local rsync_args="--archive --verbose --sparse --hard-links --partial --progress --delete --bwlimit=${BWLIMIT} --exclude-from=${exclude_file}"

    [[ "$DRYRUN" == "1" ]] && rsync_args+=" --dry-run"

    log_info "Syncing local mirror for EPEL ${release} ..."

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

# Sync each release and its corresponding GPG key
for RELEASE in "${RELEASES[@]}"; do
    sync_release $RELEASE
    sync_gpg_key "$RELEASE"
done

# And finally sync the "main" non-release GPG key
sync_gpg_key ""


log_info "Finished!"

rm -f "$LOCKFILE"
