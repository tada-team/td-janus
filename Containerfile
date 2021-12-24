FROM docker.io/ubuntu:20.04 AS base-builder

COPY focal-sources.txt /etc/apt/sources.list


RUN echo "force-unsafe-io" >> "/etc/dpkg/dpkg.cfg" && \
    dpkg --add-architecture arm64 && \
    apt update && \
    DEBIAN_FRONTEND=noninteractive apt install --yes \
        build-essential devscripts debhelper equivs wget

FROM base-builder AS libsrtp-builder
ARG LIBSRTP_VERSION="2.3.0"
WORKDIR /root
COPY sha512sums_libsrtp.txt /root/sha512sums.txt
RUN wget "https://github.com/cisco/libsrtp/archive/refs/tags/v${LIBSRTP_VERSION}.tar.gz" \
        --output-document "libsrtp_${LIBSRTP_VERSION}.orig.tar.gz" && \
    sha512sum --check /root/sha512sums.txt && \
    mkdir build && \
    tar --strip-components=1 --directory=build \
        --extract --file "libsrtp_${LIBSRTP_VERSION}.orig.tar.gz"
COPY libsrtp-debian /root/build/debian

ARG BUILD_ARCH="arm64"

WORKDIR /root/build
RUN DEBIAN_FRONTEND=noninteractive \
    mk-build-deps \
    --tool 'apt --yes -o Debug::pkgProblemResolver=yes --no-install-recommends' \
    --host-arch "${BUILD_ARCH}" debian/control \
    --install --remove
RUN dpkg-buildpackage --host-arch "${BUILD_ARCH}" --unsigned-source --unsigned-buildinfo --unsigned-changes


FROM base-builder AS janus-builder
ARG JANUS_VERSION="0.10.10"
WORKDIR /root
COPY sha512sums_janus.txt /root/sha512sums.txt
RUN wget "https://github.com/meetecho/janus-gateway/archive/refs/tags/v${JANUS_VERSION}.tar.gz" \
        --output-document "janus_${JANUS_VERSION}.orig.tar.gz" && \
    sha512sum --check /root/sha512sums.txt && \
    mkdir build && \
    tar --strip-components=1 --directory=build \
        --extract --file "janus_${JANUS_VERSION}.orig.tar.gz"
COPY --from=libsrtp-builder /root/td-libsrtp-dev*.deb ./
RUN DEBIAN_FRONTEND=noninteractive \
    apt install --yes --no-install-recommends \
    ./*.deb
COPY janus-debian /root/build/debian

ARG BUILD_ARCH

WORKDIR /root/build
RUN DEBIAN_FRONTEND=noninteractive \
    mk-build-deps \
    --tool 'apt --yes -o Debug::pkgProblemResolver=yes --no-install-recommends' \
    --host-arch "${BUILD_ARCH}" debian/control \
    --install --remove
RUN dpkg-buildpackage --host-arch "${BUILD_ARCH}" --unsigned-source --unsigned-buildinfo --unsigned-changes
