FROM debian:jessie

# Build a new base image with:
# docker build --tag mkimage:latest .
# docker run --privileged --tty --interactive mkimage:latest bash
# service docker start
# ./update.sh jessie
# Export image with: docker save --output=[remote_image_path] [image_id]
# Import image with: docker load --input=[image_path]

RUN \
    apt-get update && \
    apt-get install -y \
        ca-certificates \
        apt-transport-https \
        wget \
        curl \
        git \
        sudo \
        debootstrap

RUN \
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
    echo "deb https://apt.dockerproject.org/repo debian-jessie main" > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y docker-engine

RUN \
    git clone https://github.com/docker/docker /root/docker && \
    ln -sf ../docker/contrib/mkimage.sh /root/docker-brew-debian/mkimage.sh

RUN rm -rf /var/lib/apt/lists/*

WORKDIR /root/docker-brew-debian

COPY . /root/docker-brew-debian
