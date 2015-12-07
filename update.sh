#!/bin/bash
set -eo pipefail

declare -A backports=(
	[wheezy]=1
	[oldstable]=1
	[jessie]=1
	[stable]=1
)

cd "$(readlink -f "$(dirname "$BASH_SOURCE")")"

versions=( "$@" )
if [ ${#versions[@]} -eq 0 ]; then
	versions=( */ )
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

vercomp () {
	if [[ "$1" == "$2" ]]
	then
		return 0
	fi
	local IFS=.
	local i ver1=($1) ver2=($2)
	# fill empty fields in ver1 with zeros
	for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
	do
		ver1[i]=0
	done
	for ((i=0; i<${#ver1[@]}; i++))
	do
		if [[ -z ${ver2[i]} ]]
		then
			# fill empty fields in ver2 with zeros
			ver2[i]=0
		fi
		if ((10#${ver1[i]} > 10#${ver2[i]}))
		then
			return 1
		fi
		if ((10#${ver1[i]} < 10#${ver2[i]}))
		then
			return 2
		fi
	done
	return 0
}

compareversions () {
	vercomp "$1" "$2"
	case $? in
		0) op='=';;
		1) op='>';;
		2) op='<';;
	esac
	if [[ $op != $3 ]]
	then
		return 1
	else
		return 0
	fi
}

for version in "${versions[@]}"; do
	dir="$(readlink -f "$version")"
	variant="$(get_part "$dir" variant 'minbase')"
	components="$(get_part "$dir" components 'main')"
	include="$(get_part "$dir" include '')"
	suite="$(get_part "$dir" suite "$version")"
	mirror="$(get_part "$dir" mirror '')"
	script="$(get_part "$dir" script '')"

	args=( -d "$dir" debootstrap )
	[ -z "$variant" ] || args+=( --variant="$variant" )
	[ -z "$components" ] || args+=( --components="$components" )
	[ -z "$include" ] || args+=( --include="$include" )

	debootstrapVersion="$(debootstrap --version)"
	debootstrapVersion="${debootstrapVersion##* }"
	debootstrapVersion="${debootstrapVersion%-*}"
	if compareversions "$debootstrapVersion" 1.0.69 '='; then
		args+=( --force-check-gpg )
	elif compareversions "$debootstrapVersion" 1.0.69 '>'; then
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
		docker run -it --rm "${repo}:${suite}" bash -xc '
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

latest="$(get_part . latest '')"
if [ "$latest" ]; then
	( set -x && docker tag -f "${repo}:${latest}" "${repo}:latest" )
fi
