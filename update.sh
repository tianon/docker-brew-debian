#!/bin/bash
set -eo pipefail

cd "$(readlink -f "$(dirname "$BASH_SOURCE")")"

declare -A codenameCache=()
codename() {
	local suite="$1"; shift
	if [ -z "${codenameCache[$suite]}" ]; then
		local ret="$(curl -fsSL "http://httpredir.debian.org/debian/dists/$suite/Release" | awk -F ': ' '$1 == "Codename" { print $2 }' || true)"
		codenameCache[$suite]="${ret:-$suite}"
	fi
	echo "${codenameCache[$suite]}"
}

declare -A backports=(
	[stable]=1
	[oldstable]=1
	[$(codename stable)]=1
	[$(codename oldstable)]=1
)

declare -A unstableSuites=(
	[unstable]=1
	[testing]=1
	[$(codename unstable)]=1
	[$(codename testing)]=1
)

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	branch="$(git describe --contains --all HEAD)"
	case "$branch" in
		dist-stable)
			for suite in */; do
				suite="${suite%/}"
				[ -z "${unstableSuites[$suite]}" ] || continue
				versions+=( "$suite" )
			done
			;;
		dist-unstable)
			for suite in "${!unstableSuites[@]}"; do
				if [ -d "$suite" ]; then
					versions+=( "$suite" )
				fi
			done
			;;
		*)
			versions=( */ )
			;;
	esac
fi
versions=( "${versions[@]%/}" )

get_part() {
	dir="$1"
	shift
	part="$1"
	shift
	if [ -f "$dir/$part" ]; then
		cat "$dir/$part"
		return 0
	fi
	if [ -f "$part" ]; then
		cat "$part"
		return 0
	fi
	if [ $# -gt 0 ]; then
		echo "$1"
		return 0
	fi
	return 1
}

repo="$(get_part . repo '')"
if [ "$repo" ]; then
	origRepo="$repo"
	if [[ "$repo" != */* ]]; then
		user="$(docker info | awk '/^Username:/ { print $2 }')"
		if [ "$user" ]; then
			repo="$user/$repo"
		fi
	fi
fi

latest="$(get_part . latest '')"
for version in "${versions[@]}"; do
	dir="$(readlink -f "$version")"
	variant="$(get_part "$dir" variant 'minbase')"
	components="$(get_part "$dir" components 'main')"
	include="$(get_part "$dir" include '')"
	arch="$(get_part "$dir" arch '')"
	mergedUsr="$(get_part "$dir" merged-usr '')"
	suite="$(get_part "$dir" suite "$version")"
	mirror="$(get_part "$dir" mirror '')"
	script="$(get_part "$dir" script '')"
	
	args=( -d "$dir" debootstrap )
	[ -z "$variant" ] || args+=( --variant="$variant" )
	[ -z "$components" ] || args+=( --components="$components" )
	[ -z "$include" ] || args+=( --include="$include" )
	[ -z "$arch" ] || args+=( --arch="$arch" )
	[ -z "$mergedUsr" ] || args+=( --merged-usr )
	
	debootstrapVersion="$(debootstrap --version)"
	debootstrapVersion="${debootstrapVersion##* }"
	if dpkg --compare-versions "$debootstrapVersion" '>=' '1.0.69'; then
		args+=( --force-check-gpg )
	fi
	
	args+=( "$suite" )
	if [ "$mirror" ]; then
		args+=( "$mirror" )
		if [ "$script" ]; then
			args+=( "$script" )
		fi
	fi
	
	mkimage="$(readlink -f "${MKIMAGE:-"mkimage.sh"}")"
	{
		echo "$(basename "$mkimage") ${args[*]/"$dir"/.}"
		echo
		echo 'https://github.com/docker/docker/blob/master/contrib/mkimage.sh'
	} > "$dir/build-command.txt"
	
	sudo nice ionice -c 3 "$mkimage" "${args[@]}" 2>&1 | tee "$dir/build.log"
	
	sudo chown -R "$(id -u):$(id -g)" "$dir"
	
	if [ "$repo" ]; then
		( set -x && docker build -t "${repo}:${suite}" "$dir" )
		if [ "$suite" != "$version" ]; then
			( set -x && docker tag "${repo}:${suite}" "${repo}:${version}" )
		fi
		if [ "$suite" = "$latest" ]; then
			( set -x && docker tag "$repo:$suite" "$repo:latest" )
		fi
		docker run --rm "${repo}:${suite}" bash -xc '
			cat /etc/apt/sources.list
			echo
			cat /etc/os-release 2>/dev/null
			echo
			cat /etc/lsb-release 2>/dev/null
			echo
			cat /etc/debian_version 2>/dev/null
			true
		'
		docker run --rm "${repo}:${suite}" dpkg-query -f '${Package}\t${Version}\n' -W > "$dir/build.manifest"
		
		if [ "${backports[$suite]}" ]; then
			mkdir -p "$dir/backports"
			echo "FROM $origRepo:$suite" > "$dir/backports/Dockerfile"
			cat >> "$dir/backports/Dockerfile" <<-'EOF'
				RUN awk '$1 ~ "^deb" { $3 = $3 "-backports"; print; exit }' /etc/apt/sources.list > /etc/apt/sources.list.d/backports.list
			EOF
		fi
	fi
done
