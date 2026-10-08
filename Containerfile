##
## Start with Fedora 44, the latest stable Fedora release, and download
## the Fedora SRPM files for the missing FlightGear
## dependencies. These were determined manually to find the minimal set
## of build and runtime dependencies.
##
## Key artifact: missing-rpms.tgz
##
FROM fedora:44 AS fedora
COPY /*-dependencies.txt /

# update and install xargs and find (download is built into dnf5)
RUN    dnf -y update \
    && dnf -y install findutils \
    && dnf -y clean all

# download and tgz the missing dependency SRPM files.
RUN    cat build-dependencies.txt runtime-dependencies.txt | \
           xargs dnf -y download --srpm \
    && tar zcvf missing-rpms.tgz *.rpm

##
## Build the missing FlightGear SRPMs on RHEL9
##
FROM registry.access.redhat.com/ubi9/ubi:9.8 AS build
COPY --from=fedora /missing-rpms.tgz / 

# The build needs the full RHEL repos, including codeready-builder. On a
# subscribed RHEL host podman passes the host subscription into the
# container. On any other host (Fedora, Ubuntu, etc.) register the
# container itself using the SCA credentials passed in as a build secret.
RUN    --mount=type=secret,id=sca \
       if ls /etc/pki/entitlement-host/*.pem >/dev/null 2>&1; \
       then \
           echo "Using the host's RHEL subscription"; \
       else \
           . /run/secrets/sca \
           && subscription-manager register \
                  --username "$SCA_USER" --password "$SCA_PASS"; \
       fi

# update and then set up the build environment
RUN    dnf -y update \
    && dnf -y install rpmdevtools tcl findutils \
           https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
    && dnf -y clean all

# install all the build dependencies
RUN    mkdir -p srpms \
    && tar zxvf missing-rpms.tgz -C srpms \
    && ls srpms/*.src.rpm | xargs dnf -y builddep --skip-unavailable --srpm \
           --enablerepo=codeready-builder-for-rhel-9-$(uname -m)-rpms

# at this point, we need to attempt to build each SRPM and then install
# the resulting RPMs until they all eventually build. This could probably
# be more efficient
RUN    mkdir -p rpms completed-srpms \
    && while [ ! -z "$(ls -A srpms)" ]; \
       do \
           for i in $(ls srpms/*.src.rpm); \
           do \
               rm -fr /root/rpmbuild; \
               rpmbuild --rebuild $i; \
               if [ ! -z "$(find /root/rpmbuild/RPMS -type f -name '*.rpm')" ]; \
               then \
                   mv $i completed-srpms; \
                   cp $(find /root/rpmbuild/RPMS/ -type f -name '*.rpm' | grep -vE 'debugsource|debuginfo') rpms; \
                   dnf -y install \
                       --enablerepo=codeready-builder-for-rhel-9-$(uname -m)-rpms \
                       rpms/*.rpm; \
               fi; \
           done; \
       done

# release the container's registration, if it made one
RUN    subscription-manager unregister || true

##
## Export only the built RPMs to the host via --output
##
FROM scratch
COPY --from=build /rpms/ /
