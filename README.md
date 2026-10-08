# Build FlightGear flight simulator for RHEL 9
Use a Containerfile with multi-stage builds to sort out all the missing
dependencies and build the RPMs for RHEL 9.8.

Everything runs inside containers, so you can build on any Linux host
with podman (4.0 or later) or docker (with BuildKit, the default since
Docker 23). The RHEL build stage registers itself with your Red Hat
account, so the host doesn't need to run RHEL or be subscribed.

## Install a container engine
On Fedora, RHEL, or CentOS Stream

    sudo dnf -y install podman

On Ubuntu or Debian

    sudo apt-get update
    sudo apt-get -y install podman

Docker works too if you already have it.

## Set your Red Hat credentials
Clone this repository and edit `demo.conf` to set your Red Hat customer
portal username and password. These are passed to the build as a secret
and are not stored in any image layer. A free
[Red Hat Developer](https://developers.redhat.com/register) account
works.

If you build with podman on a RHEL host that is already registered, the
build uses the host's subscription and `demo.conf` is not needed.

## Build the RPMs

    cd ~/build-flightgear-rpms
    ./build.sh

The script uses podman if it's installed and docker otherwise. Set
`ENGINE=docker` to choose docker explicitly.

The RPMs will be in the `flightgear-rpms` directory when the build
finishes. You can discard the `-devel` RPMs as you will no longer need
those.

    rm -f flightgear-rpms/*-devel*

Not all of the RPMs are necessary to install FlightGear. You only need
the ones for missing runtime dependencies. With a little trial and error,
I narrowed the list to everything in `runtime-dependencies.txt`.
