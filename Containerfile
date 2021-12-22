FROM docker.io/ubuntu:20.04

COPY focal-sources.txt /etc/apt/sources.list
COPY sha512sums.txt /root

RUN echo "force-unsafe-io" >> "/etc/dpkg/dpkg.cfg" && \
    dpkg --add-architecture arm64 && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install --yes \
        build-essential devscripts debhelper equivs wget

ARG VERSION="0.10.10"
WORKDIR /root
RUN wget "https://github.com/meetecho/janus-gateway/archive/refs/tags/v${VERSION}.tar.gz" \
        --output-document "janus_${VERSION}.orig.tar.gz" && \
    sha512sum --check /root/sha512sums.txt && \
    mkdir build && \
    tar --strip-components=1 --directory=build \
        --extract --file "janus_${VERSION}.orig.tar.gz"

COPY debian /root/build/debian

WORKDIR /root/build
ARG BUILD_ARCH="arm64"
RUN DEBIAN_FRONTEND=noninteractive \
    mk-build-deps \
    --tool 'apt --yes -o Debug::pkgProblemResolver=yes --no-install-recommends' \
    --host-arch "${BUILD_ARCH}" debian/control \
    --install --remove
RUN dpkg-buildpackage --host-arch "${BUILD_ARCH}" --unsigned-source --unsigned-buildinfo --unsigned-changes
