FROM docker.io/ubuntu:20.04

COPY focal-sources.txt /etc/apt/sources.list
COPY sha512sums.txt /root

RUN echo "force-unsafe-io" >> "/etc/dpkg/dpkg.cfg" && \
    dpkg --add-architecture arm64 && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install --yes \
        build-essential devscripts debhelper equivs wget

ARG LIBSRTP_VERSION="2.3.0"
ARG JANUS_VERSION="0.10.10"
WORKDIR /root
RUN wget "https://github.com/cisco/libsrtp/archive/refs/tags/v${LIBSRTP_VERSION}.tar.gz" \
        --output-document "libsrtp_${LIBSRTP_VERSION}.orig.tar.gz" && \
    wget "https://github.com/meetecho/janus-gateway/archive/refs/tags/v${JANUS_VERSION}.tar.gz" \
        --output-document "janus_${JANUS_VERSION}.orig.tar.gz" && \
    sha512sum --check /root/sha512sums.txt && \
    mkdir build-janus build-libsrtp && \
    tar --strip-components=1 --directory=build-janus \
        --extract --file "janus_${JANUS_VERSION}.orig.tar.gz" && \
    tar --strip-components=1 --directory=build-libsrtp \
        --extract --file "libsrtp_${LIBSRTP_VERSION}.orig.tar.gz"

COPY libsrtp-debian /root/build-libsrtp/debian
COPY janus-debian /root/build-janus/debian

ARG BUILD_ARCH="arm64"

WORKDIR /root/build-libsrtp
RUN DEBIAN_FRONTEND=noninteractive \
    mk-build-deps \
    --tool 'apt --yes -o Debug::pkgProblemResolver=yes --no-install-recommends' \
    --host-arch "${BUILD_ARCH}" debian/control \
    --install --remove
RUN dpkg-buildpackage --host-arch "${BUILD_ARCH}" --unsigned-source --unsigned-buildinfo --unsigned-changes

WORKDIR /root
RUN DEBIAN_FRONTEND=noninteractive \
    apt install --yes --no-install-recommends \
    ./*.deb

WORKDIR /root/build-janus
RUN DEBIAN_FRONTEND=noninteractive \
    mk-build-deps \
    --tool 'apt --yes -o Debug::pkgProblemResolver=yes --no-install-recommends' \
    --host-arch "${BUILD_ARCH}" debian/control \
    --install --remove
RUN dpkg-buildpackage --host-arch "${BUILD_ARCH}" --unsigned-source --unsigned-buildinfo --unsigned-changes
