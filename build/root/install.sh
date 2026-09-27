#!/bin/bash

# exit script if return code != 0
set -e

# app name from buildx arg, used in healthcheck to identify app and monitor correct process
APPNAME="${1}"
shift

# release tag name from buildx arg, stripped of build ver using string manipulation
RELEASETAG="${1}"
shift

# target arch from buildx arg
TARGETARCH="${1}"
shift

if [[ -z "${APPNAME}" ]]; then
	echo "[warn] App name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${RELEASETAG}" ]]; then
	echo "[warn] Release tag name from build arg is empty, exiting script..."
	exit 1
fi

if [[ -z "${TARGETARCH}" ]]; then
	echo "[warn] Target architecture name from build arg is empty, exiting script..."
	exit 1
fi

# write APPNAME and RELEASETAG to file to record the app name and release tag used to build the image
echo -e "export APPNAME=${APPNAME}\nexport IMAGE_RELEASE_TAG=${RELEASETAG}\n" >> '/etc/image-build-info'

# ensure we have the latest builds scripts
refresh.sh

# pacman packages
####

# define pacman packages
pacman_packages="jre8-openjdk-headless jre11-openjdk-headless jre17-openjdk-headless jre21-openjdk-headless jre-openjdk-headless gcc git libwebp rust"

# install compiled packages using pacman
if [[ -n "${pacman_packages}" ]]; then
	# arm64 currently targetting aor not archive, so we need to update the system first
	if [[ "${TARGETARCH}" == "arm64" ]]; then
		pacman -Syu --noconfirm
	fi
	pacman -S --needed $pacman_packages --noconfirm
fi

# github
####

install_path="/opt/crafty"
virtualenv_path="/opt/crafty/venv"

# download crafty from branch 'master' (no releases at this time)
# '--depth=1' ensures only latest commits to speed up download
git clone --depth=1 --branch master https://gitlab.com/crafty-controller/crafty-4 "${install_path}"

# crafty source patches
######################

# resolve stored server paths before relative path comparisons, required as this
# image symlinks persistence dirs into place, see upstream issue #752 and
# binhex/arch-crafty-4#12, patch step can be removed once upstream ships a fix

crafty_files_py="${install_path}/app/classes/web/routes/api/servers/server/files.py"
crafty_helpers_py="${install_path}/app/classes/helpers/file_helpers.py"

# both patched expressions use pathlib's Path as a bare name, so fail loudly if a
# target file disappears or upstream stops importing it (runtime-only otherwise)
for crafty_py in "${crafty_files_py}" "${crafty_helpers_py}"; do
	if [[ ! -f "${crafty_py}" ]]; then
		echo "[crit] Expected file '${crafty_py}' not found, exiting build process..."
		exit 1
	fi
	if ! grep -Eq '^from pathlib import .*\bPath\b' "${crafty_py}" \
		|| grep -Eq '^from pathlib import .*\bPath[[:space:]]+as\b' "${crafty_py}"; then
		echo "[crit] Expected Path import in '${crafty_py}', exiting build process..."
		exit 1
	fi
done

crafty_files_py_match='PurePath(raw_path), PurePath(server_path)'
crafty_files_py_replace='PurePath(raw_path), PurePath(Path(server_path).resolve())'
crafty_files_py_patched_before=$(grep -o -F "${crafty_files_py_replace}" "${crafty_files_py}" | wc -l || true)

if [[ "${crafty_files_py_patched_before}" -ne 0 ]]; then
	echo "[crit] '${crafty_files_py}' already contains the crafty server path patch, exiting build process..."
	exit 1
fi

crafty_files_py_count=$(grep -o -F "${crafty_files_py_match}" "${crafty_files_py}" | wc -l || true)

if [[ "${crafty_files_py_count}" -ne 2 ]]; then
	echo "[crit] Expected 2 crafty server path patch matches, found '${crafty_files_py_count}'..."
	echo "[crit] Unable to patch '${crafty_files_py}', exiting build process..."
	exit 1
fi

sed -i "s/${crafty_files_py_match}/${crafty_files_py_replace}/g" "${crafty_files_py}"

crafty_files_py_patched_after=$(grep -o -F "${crafty_files_py_replace}" "${crafty_files_py}" | wc -l || true)

if [[ "${crafty_files_py_patched_after}" -ne 2 ]]; then
	echo "[crit] Expected 2 crafty server path patch results, found '${crafty_files_py_patched_after}'..."
	echo "[crit] Unable to patch '${crafty_files_py}', exiting build process..."
	exit 1
fi

# resolve stored server path before walking it for backups, so excluded dirs
# (stored as relative or resolved paths) are matched when creating backups

crafty_helpers_py_match='path_to_zip: Path = Path(path_to_zip)'
crafty_helpers_py_replace='path_to_zip: Path = Path(path_to_zip).resolve()'
crafty_helpers_py_patched_before=$(grep -o -F "${crafty_helpers_py_replace}" "${crafty_helpers_py}" | wc -l || true)

if [[ "${crafty_helpers_py_patched_before}" -ne 0 ]]; then
	echo "[crit] '${crafty_helpers_py}' already contains the crafty backup exclude patch, exiting build process..."
	exit 1
fi

crafty_helpers_py_count=$(grep -o -F "${crafty_helpers_py_match}" "${crafty_helpers_py}" | wc -l || true)

if [[ "${crafty_helpers_py_count}" -ne 1 ]]; then
	echo "[crit] Expected 1 crafty backup exclude patch match, found '${crafty_helpers_py_count}'..."
	echo "[crit] Unable to patch '${crafty_helpers_py}', exiting build process..."
	exit 1
fi

sed -i "s/${crafty_helpers_py_match}/${crafty_helpers_py_replace}/" "${crafty_helpers_py}"

crafty_helpers_py_patched_after=$(grep -o -F "${crafty_helpers_py_replace}" "${crafty_helpers_py}" | wc -l || true)

if [[ "${crafty_helpers_py_patched_after}" -ne 1 ]]; then
	echo "[crit] Expected 1 crafty backup exclude patch result, found '${crafty_helpers_py_patched_after}'..."
	echo "[crit] Unable to patch '${crafty_helpers_py}', exiting build process..."
	exit 1
fi

# python
####

# use pip to install requirements for crafty as defined in requirements.txt
python.sh --requirements-path "${install_path}" --create-virtualenv 'yes' --virtualenv-path "${virtualenv_path}"

# container perms
####

# define comma separated list of paths
install_paths="/opt/crafty,/home/nobody"

# split comma separated string into list for install paths
IFS=',' read -ra install_paths_list <<< "${install_paths}"

# process install paths in the list
for i in "${install_paths_list[@]}"; do

	# confirm path(s) exist, if not then exit
	if [[ ! -d "${i}" ]]; then
		echo "[crit] Path '${i}' does not exist, exiting build process..." ; exit 1
	fi

done

# convert comma separated string of install paths to space separated, required for chmod/chown processing
install_paths=$(echo "${install_paths}" | tr ',' ' ')

# set permissions for container during build - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
chmod -R 775 ${install_paths}

# In install.sh heredoc, replace the chown section:
cat <<EOF > /tmp/permissions_heredoc
install_paths="${install_paths}"
EOF

# replace permissions placeholder string with contents of file (here doc)
sed -i '/# PERMISSIONS_PLACEHOLDER/{
    s/# PERMISSIONS_PLACEHOLDER//g
    r /tmp/permissions_heredoc
}' /usr/bin/init.sh
rm /tmp/permissions_heredoc

# env vars
####

cat <<'EOF' > /tmp/envvars_heredoc

# get latest java version for package 'jre-openjdk-headless'
latest_java_version=$(pacman -Qi jre-openjdk-headless | grep -P -o -m 1 '^Version\s*: \K.+' | grep -P -o -m 1 '^[0-9]+')

export JAVA_VERSION=$(echo "${JAVA_VERSION}" | sed -e 's~^[ \t]*~~;s~[ \t]*$~~')
if [[ ! -z "${JAVA_VERSION}" ]]; then
	echo "[info] JAVA_VERSION defined as '${JAVA_VERSION}'" | ts '%Y-%m-%d %H:%M:%.S'
else
	echo "[info] JAVA_VERSION not defined,(via -e JAVA_VERSION), defaulting to Java version 'latest'" | ts '%Y-%m-%d %H:%M:%.S'
	export JAVA_VERSION="latest"
fi

if [[ "${JAVA_VERSION}" == "8" ]]; then
	ln -fs '/usr/lib/jvm/java-8-openjdk/jre/bin/java' '/usr/bin/java'
	archlinux-java set java-8-openjdk/jre
elif [[ "${JAVA_VERSION}" == "11" ]]; then
	ln -fs '/usr/lib/jvm/java-11-openjdk/bin/java' '/usr/bin/java'
	archlinux-java set java-11-openjdk
elif [[ "${JAVA_VERSION}" == "17" ]]; then
	ln -fs '/usr/lib/jvm/java-17-openjdk/bin/java' '/usr/bin/java'
	archlinux-java set java-17-openjdk
elif [[ "${JAVA_VERSION}" == "21" ]]; then
	ln -fs '/usr/lib/jvm/java-21-openjdk/bin/java' '/usr/bin/java'
	archlinux-java set java-21-openjdk
elif [[ "${JAVA_VERSION}" == "latest" ]]; then
	ln -fs "/usr/lib/jvm/java-${latest_java_version}-openjdk/bin/java" '/usr/bin/java'
	archlinux-java set java-${latest_java_version}-openjdk
else
	echo "[warn] Java version '${JAVA_VERSION}' not valid, defaulting to Java version 'latest" | ts '%Y-%m-%d %H:%M:%.S'
	ln -fs "/usr/lib/jvm/java-${latest_java_version}-openjdk/bin/java" '/usr/bin/java'
	archlinux-java set java-${latest_java_version}-openjdk
fi

EOF

# replace env vars placeholder string with contents of file (here doc)
sed -i '/# ENVVARS_PLACEHOLDER/{
    s/# ENVVARS_PLACEHOLDER//g
    r /tmp/envvars_heredoc
}' /usr/bin/init.sh
rm /tmp/envvars_heredoc

# cleanup
cleanup.sh
