# **DEPRECATED**

This repository is now deprecated in favor of https://github.com/debuerreotype/docker-debian-artifacts, which builds reproducible Debian rootfs tarballs using https://github.com/debuerreotype/debuerreotype.

# About this Repo

This is the Git repo of the Docker [official image](https://docs.docker.com/docker-hub/official_repos/) for [debian](https://registry.hub.docker.com/_/debian/). See [the Docker Hub page](https://registry.hub.docker.com/_/debian/) for the full readme on how to use this Docker image and for information regarding contributing and issues.

The full readme is generated over in [docker-library/docs](https://github.com/docker-library/docs), specificially in [docker-library/docs/debian](https://github.com/docker-library/docs/tree/master/debian).

## Maintainers

This image is maintained by [tianon](https://nm.debian.org/public/person/tianon) and [paultag](https://nm.debian.org/public/person/paultag), who are Debian Developers.

## Building

This image is built using [`contrib/mkimage.sh` from `github.com/docker/docker`](https://github.com/docker/docker/blob/master/contrib/mkimage.sh), where the interesting bits live in [`contrib/mkimage/debootstrap`](https://github.com/docker/docker/blob/master/contrib/mkimage/debootstrap).  The `mkimage.sh` file here is a symlink to my local copy of that `mkimage.sh` script (which enables it to find the `debootstrap` script it needs).

The [`master` branch](https://github.com/tianon/docker-brew-debian) contains the scripts and is where any "development" happens, and the [`dist` branch](https://github.com/tianon/docker-brew-debian/tree/dist) contains the built tarballs and the build logs.
