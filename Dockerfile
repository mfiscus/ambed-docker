# syntax=docker/dockerfile:1-labs
FROM amd64/ubuntu:latest AS base

ENTRYPOINT ["/init"]

ENV TERM="xterm" LANG="C.UTF-8" LC_ALL="C.UTF-8"
ARG ARCH=x86_64 S6_OVERLAY_VERSION=3.1.5.0 S6_RCD_DIR=/etc/s6-overlay/s6-rc.d S6_LOGGING=1 S6_KEEP_ENV=1
ARG AMBED_DIR=/ambed AMBED_INST_DIR=/src/ambed USE_AGC=0
ARG FTDI_INST_DIR=/src/ftdi

# install dependencies
RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections && \
    apt update && \
    apt upgrade -y && \
    apt install -y \
    build-essential \
    lsof

# Setup directories
RUN mkdir -p \
    ${AMBED_DIR} \
    ${AMBED_INST_DIR} \
    ${FTDI_INST_DIR} 

# Fetch and extract S6 overlay
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz

ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${ARCH}.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-${ARCH}.tar.xz

# Clone xlxd repository
ADD --keep-git-dir=true https://github.com/LX3JL/xlxd.git#master ${AMBED_INST_DIR}

# Download and extract ftdi driver
# Raspberry Pi (legacy)
#ADD https://www.ftdichip.com/Drivers/D2XX/Linux/libftd2xx-arm-v7-hf-1.4.27.tgz /tmp
# Raspberry Pi 4 and up
#ADD https://www.ftdichip.com/Drivers/D2XX/Linux/libftd2xx-arm-v8-1.4.27.tgz /tmp
# X64 (working)
#ADD http://www.ftdichip.com/Drivers/D2XX/Linux/libftd2xx-${ARCH}-1.4.6.tgz /tmp
# X64 (latest)
ADD https://ftdichip.com/wp-content/uploads/2022/07/libftd2xx-${ARCH}-1.4.27.tgz /tmp
RUN tar -C ${FTDI_INST_DIR} -zxvf /tmp/libftd2xx-${ARCH}-*.tgz

# Copy in source code (use local sources if repositories go down)
#COPY src/ /

# Install FTDI driver
RUN cp ${FTDI_INST_DIR}/release/build/libftd2xx.* /usr/local/lib && \
    chmod 0755 /usr/local/lib/libftd2xx.so.* && \
    ln -sf /usr/local/lib/libftd2xx.so.* /usr/local/lib/libftd2xx.so

# Perform pre-compiliation configurations
RUN sed "s/\(USE_AGC[[:space:]]*\)[[:digit:]]/\1${USE_AGC}/g" ${AMBED_INST_DIR}${AMBED_DIR}/main.h && \
    cp ${AMBED_INST_DIR}${AMBED_DIR}/main.h ${AMBED_DIR}/main.h.customized

# Compile and install AMBE server
RUN cd ${AMBED_INST_DIR}${AMBED_DIR} && \
    make clean && \
    make && \
    make install && \
    cp ${AMBED_INST_DIR}${AMBED_DIR}${AMBED_DIR} ${AMBED_DIR}

# Copy in s6 service definitions and scripts
COPY root/ /

# Cleanup
RUN apt -y purge build-essential && \
    apt -y autoremove && \
    apt -y clean && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /tmp/* && \
    rm -rf /var/tmp/* && \
    rm -rf /src

#UDP port 10100 (AMBE controller port)
EXPOSE 10100/udp
#UDP port 10101 - 10199 (AMBE transcoding port)
EXPOSE 10101-10199/udp

HEALTHCHECK --interval=5s --timeout=2s --retries=20 CMD /healthcheck.sh || exit 1