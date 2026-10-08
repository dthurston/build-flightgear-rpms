#!/usr/bin/env bash
#
# Build the FlightGear RPMs with podman or docker on any Linux host.
# Prompts for the Red Hat username and password used to register the
# RHEL build container. The RPMs are written to ./flightgear-rpms
#

cd "$(dirname "$0")"

ENGINE=${ENGINE:-$(command -v podman || command -v docker)}
if [[ -z "$ENGINE" ]]
then
    echo
    echo "ERROR: Install podman or docker first"
    echo
    exit 1
fi

# The credentials are handed to the build as secret files, which never
# end up in an image layer. Remove them however this script exits.
SECRETS=$(mktemp -d)
trap 'rm -rf "$SECRETS"' EXIT
chmod 700 "$SECRETS"

# podman on a subscribed RHEL host passes the host's subscription into
# the build, so no credentials are needed there
if [[ "$(basename "$ENGINE")" == podman ]] && ls /etc/pki/entitlement/*.pem >/dev/null 2>&1
then
    echo "Using this host's RHEL subscription"
    : > "$SECRETS/sca_user"
    : > "$SECRETS/sca_pass"
else
    read -r -p "Red Hat username: " SCA_USER
    read -r -s -p "Red Hat password: " SCA_PASS
    echo

    if [[ -z "$SCA_USER" || -z "$SCA_PASS" ]]
    then
        echo
        echo "ERROR: Both a username and a password are required"
        echo
        exit 1
    fi

    printf '%s' "$SCA_USER" > "$SECRETS/sca_user"
    printf '%s' "$SCA_PASS" > "$SECRETS/sca_pass"
    unset SCA_PASS
fi

# docker needs BuildKit for build secrets and --output
export DOCKER_BUILDKIT=1

mkdir -p flightgear-rpms
"$ENGINE" build \
    --secret id=sca_user,src="$SECRETS/sca_user" \
    --secret id=sca_pass,src="$SECRETS/sca_pass" \
    --output type=local,dest=flightgear-rpms \
    -f Containerfile .
