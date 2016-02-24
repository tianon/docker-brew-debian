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

branches=( master dist-stable dist-unstable )

for branch in "${branches[@]}"; do
	if [ "$branch" = 'master' ]; then
		continue
	fi
	commitRange="master..$branch"
	commitCount="$(git rev-list "$commitRange" --count 2>/dev/null || true)"
	if [ "$commitCount" ] && [ "$commitCount" -gt 0 ]; then
		echo
		echo '# commits:' "($commitRange)"
		git log --format=format:'- %h %s%n%w(0,2,2)%b' "$commitRange" | sed 's/^/#  /'
	fi
done

for version in "${versions[@]}"; do
	tarball="$version/rootfs.tar.xz"
	commit="$(git log -1 --format='format:%H' "${branches[@]}" -- "$tarball")"
	versionAliases=()
	if [ -z "${noVersion[$version]}" ]; then
		fullVersion="$(git show "$commit:$tarball" | tar -xvJ etc/debian_version --to-stdout 2>/dev/null || true)"
		if [ -z "$fullVersion" ] || [[ "$fullVersion" == */sid ]]; then
			fullVersion="$(eval "$(git show "$commit:$tarball" | tar -xvJ etc/os-release --to-stdout 2>/dev/null || true)" && echo "$VERSION" | cut -d' ' -f1)"
			if [ -z "$fullVersion" ]; then
				# lucid...
				fullVersion="$(eval "$(git show "$commit:$tarball" | tar -xvJ etc/lsb-release --to-stdout 2>/dev/null || true)" && echo "$DISTRIB_DESCRIPTION" | cut -d' ' -f2)" # DISTRIB_DESCRIPTION="Ubuntu 10.04.4 LTS"
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
	versionAliases+=( $version $(git show "$commit:$version/suite" 2>/dev/null || true) ${aliases[$version]} )
	
	echo
	for va in "${versionAliases[@]}"; do
		echo "$va: ${url}@${commit} $version"
	done
	
	if [ "$(git show "$commit:$version/backports/Dockerfile" 2>/dev/null || true)" ]; then
		echo
		echo "$version-backports: ${url}@${commit} $version/backports"
	fi
done

dockerfilesGit='git://github.com/tianon/dockerfiles'
dockerfiles='https://github.com/tianon/dockerfiles/commits/master/debian'
rcBuggyCommit="$(curl -fsSL "$dockerfiles/rc-buggy/Dockerfile.atom" | tac|tac | awk -F '[ \t]*[<>/]+' '$2 == "id" && $3 ~ /Commit/ { print $4; exit }')"
experimentalCommit="$(curl -fsSL "$dockerfiles/experimental/Dockerfile.atom" | tac|tac | awk -F '[ \t]*[<>/]+' '$2 == "id" && $3 ~ /Commit/ { print $4; exit }')"
cat <<-EOF

rc-buggy: $dockerfilesGit@$rcBuggyCommit debian/rc-buggy
experimental: $dockerfilesGit@$experimentalCommit debian/experimental
EOF
