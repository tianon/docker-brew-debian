#!/bin/bash

# debootstrap install packages in two different ways:
# (1) By simply extracting the contents of a package directly to the root disk.
# (2) Via dpkg
# Since we want to exclude files during both (1) and (2) we use two different
# methods. extract_dpkg_deb_data() is used for (1) while the dpkg
# config settings are used for (2).


# (1) Redefine extract_dpkg_deb_data() from /usr/share/debootstrap/functions
# so that we may exclude certain files during bootstrapping.
extract_dpkg_deb_data () {
    local pkg="$1"
    local excludes_file="/tmp/debootstrap-excludes"
    local untar_exclude_pattern='./usr/share/locale/.\+\|./usr/share/man/.\+\|./usr/share/doc/.\+'
    local untar_include_paths='./usr/share/locale/locale.alias
./usr/share/man/man1
./usr/share/man/man2
./usr/share/man/man3
./usr/share/man/man4
./usr/share/man/man5
./usr/share/man/man6
./usr/share/man/man7
./usr/share/man/man8
./usr/share/man/man9'
    # Create an exclusion file we can use when extracting:
    # 1. Get the fs tarfile from the dpkg
    # 2. Get a list of all the files in the tar
    # 3. Filter out all paths not relating to the stuff we want to filter
    # 4. Take out the paths that we *do* want to keep
    # 5. Save the result so that we can use it when extracting
    #    (and avoid exit status >0 if no matches are found)
    dpkg-deb --fsys-tarfile "$pkg" | \
        tar -tf - | \
        grep "$untar_exclude_pattern" | \
        grep --invert-match --fixed-strings "$untar_include_paths" \
        > "$excludes_file" || true
    # Do what extract_dpkg_deb_data() normally would do,
    # but exclude the files from the list we just created.
    dpkg-deb --fsys-tarfile "$pkg" | tar --exclude-from "$excludes_file" -xf -
    rm "$excludes_file"
}


# (2) Preconfigure dpkg to not install locales, manpages and docs
# (but keep some of the files to avoid breakage).
mkdir -p "$TARGET/etc/dpkg/dpkg.cfg.d/"
cat > "$TARGET/etc/dpkg/dpkg.cfg.d/10filter-locales" <<EOF
path-exclude=/usr/share/locale/*
path-include=/usr/share/locale/locale.alias
EOF
cat > "$TARGET/etc/dpkg/dpkg.cfg.d/10filter-manpages" <<EOF
path-exclude=/usr/share/man/*
path-include=/usr/share/man/man[1-9]
EOF
cat > "$TARGET/etc/dpkg/dpkg.cfg.d/10exclude-docs" <<EOF
path-exclude=/usr/share/doc/*
EOF


# The real bootstrapping scripts are in /usr/share/debootstrap/scripts/
# We obviously still want to run on of those.
# This is almost a direct copy from debootstrap where it determines
# which script to run (with the "custom script" part left out).
SCRIPT="$DEBOOTSTRAP_DIR/scripts/$SUITE"
if [ -n "$VARIANT" ] && [ -e "${SCRIPT}.${VARIANT}" ]; then
    SCRIPT="${SCRIPT}.${VARIANT}"
fi

. "$SCRIPT"
