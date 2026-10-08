#!/usr/bin/env bash
#
# Build the FlightGear RPMs with podman or docker on any Linux host.
# The RPMs are written to ./flightgear-rpms
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

# docker needs BuildKit for build secrets and --output
export DOCKER_BUILDKIT=1

mkdir -p flightgear-rpms
"$ENGINE" build \
    --secret id=sca,src=demo.conf \
    --output type=local,dest=flightgear-rpms \
    -f Containerfile .
