#!/bin/bash
set -e

declare -A aliases
aliases=(
	[$(cat latest)]='latest'
)
declare -A noVersion
noVersion=(
	[oldstable]=1
	[stable]=1
	[testing]=1
	[unstable]=1
)

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

versions=( */ )
versions=( "${versions[@]%/}" )
url='git://github.com/tianon/docker-brew-debian'

echo '# maintainer: Tianon Gravi <admwiggin@gmail.com> (@tianon)'

for version in "${versions[@]}"; do
	commit="$(git log -1 --format='format:%H' "$version")"
	versionAliases=()
	if [ -z "${noVersion[$version]}" ]; then
		fullVersion="$(tar -xvf "$version/rootfs.tar.xz" etc/debian_version --to-stdout 2>/dev/null)"
		if [ -z "$fullVersion" ] || [[ "$fullVersion" == */sid ]]; then
			fullVersion="$(eval "$(tar -xvf "$version/rootfs.tar.xz" etc/os-release --to-stdout 2>/dev/null)" && echo "$VERSION" | cut -d' ' -f1)"
			if [ -z "$fullVersion" ]; then
				# lucid...
				fullVersion="$(eval "$(tar -xvf "$version/rootfs.tar.xz" etc/lsb-release --to-stdout 2>/dev/null)" && echo "$DISTRIB_DESCRIPTION" | cut -d' ' -f2)" # DISTRIB_DESCRIPTION="Ubuntu 10.04.4 LTS"
			fi
		else
			while [ "${fullVersion%.*}" != "$fullVersion" ]; do
				versionAliases+=( $fullVersion )
				fullVersion="${fullVersion%.*}"
			done
		fi
		if [ "$fullVersion" != "$version" ]; then
			versionAliases+=( $fullVersion )
		fi
	fi
	versionAliases+=( $version $(cat "$version/suite" 2>/dev/null || true) ${aliases[$version]} )
	
	echo
	for va in "${versionAliases[@]}"; do
		echo "$va: ${url}@${commit} $version"
	done
done

dockerfiles='git://github.com/tianon/dockerfiles'
commit="$(git ls-remote "$dockerfiles" HEAD | cut -d$'\t' -f1)"
cat <<-EOF

rc-buggy: $dockerfiles@$commit debian/rc-buggy
experimental: $dockerfiles@$commit debian/experimental
EOF
