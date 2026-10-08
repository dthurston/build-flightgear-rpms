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
FROM registry.redhat.io/ubi9/ubi:9.8
COPY --from=fedora /missing-rpms.tgz / 

# update and then set up the build environment
RUN    dnf -y update \
    && dnf -y install rpmdevtools tcl findutils \
           https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm \
    && dnf -y clean all

# install all the build dependencies
RUN    mkdir -p srpms \
    && tar zxvf missing-rpms.tgz -C srpms \
    && ls srpms/*.src.rpm | xargs dnf -y builddep --skip-unavailable --srpm \
           --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms

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
                       --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
                       rpms/*.rpm; \
               fi; \
           done; \
       done
