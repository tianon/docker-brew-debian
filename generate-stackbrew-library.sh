#!/bin/bash
set -e

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

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
	[sid]=1
)

versions=( */ )
versions=( "${versions[@]%/}" )
url='git://github.com/tianon/docker-brew-debian'

cat <<-'EOH'
# maintainer: Tianon Gravi <tianon@debian.org> (@tianon)
# maintainer: Paul Tagliamonte <paultag@debian.org> (@paultag)
EOH

commitRange='master..dist'
commitCount="$(git rev-list "$commitRange" --count 2>/dev/null || true)"
if [ "$commitCount" ] && [ "$commitCount" -gt 0 ]; then
	echo
	echo '# commits:' "($commitRange)"
	git log --format=format:'- %h %s%n%w(0,2,2)%b' "$commitRange" | sed 's/^/#  /'
fi

for version in "${versions[@]}"; do
	commit="$(git log -1 --format='format:%H' -- "$version")"
	versionAliases=()
	if [ -z "${noVersion[$version]}" ]; then
		tarball="$version/rootfs.tar.xz"
		fullVersion="$(tar -xvf "$tarball" etc/debian_version --to-stdout 2>/dev/null)"
		if [ -z "$fullVersion" ] || [[ "$fullVersion" == */sid ]]; then
			fullVersion="$(eval "$(tar -xvf "$tarball" etc/os-release --to-stdout 2>/dev/null)" && echo "$VERSION" | cut -d' ' -f1)"
			if [ -z "$fullVersion" ]; then
				# lucid...
				fullVersion="$(eval "$(tar -xvf "$tarball" etc/lsb-release --to-stdout 2>/dev/null)" && echo "$DISTRIB_DESCRIPTION" | cut -d' ' -f2)" # DISTRIB_DESCRIPTION="Ubuntu 10.04.4 LTS"
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
	
	if [ -s "$version/backports/Dockerfile" ]; then
		echo
		echo "$version-backports: ${url}@${commit} $version/backports"
	fi
done

dockerfiles='git://github.com/tianon/dockerfiles'
commit="$(git ls-remote "$dockerfiles" HEAD | cut -d$'\t' -f1)"
cat <<-EOF

rc-buggy: $dockerfiles@$commit debian/rc-buggy
experimental: $dockerfiles@$commit debian/experimental
EOF
