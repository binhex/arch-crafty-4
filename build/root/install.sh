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
echo -e "export APPNAME=${APPNAME}\nexport IMAGE_RELEASE_TAG=${RELEASETAG}\nexport TARGETARCH=${TARGETARCH}\n" >> '/etc/image-build-info'

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

# create file with contents of here doc, note EOF is NOT quoted to allow us to expand current variable 'install_paths'
# we use escaping to prevent variable expansion for PUID and PGID, as we want these expanded at runtime of init.sh
cat <<EOF > /tmp/permissions_heredoc

# get previous puid/pgid (if first run then will be empty string)
previous_puid=\$(cat "/root/puid" 2>/dev/null || true)
previous_pgid=\$(cat "/root/pgid" 2>/dev/null || true)

# if first run (no puid or pgid files in /tmp) or the PUID or PGID env vars are different
# from the previous run then re-apply chown with current PUID and PGID values.
if [[ ! -f "/root/puid" || ! -f "/root/pgid" || "\${previous_puid}" != "\${PUID}" || "\${previous_pgid}" != "\${PGID}" ]]; then

	# set permissions inside container - Do NOT double quote variable for install_paths otherwise this will wrap space separated paths as a single string
	chown -R "\${PUID}":"\${PGID}" ${install_paths}

fi

# write out current PUID and PGID to files in /root (used to compare on next run)
echo "\${PUID}" > /root/puid
echo "\${PGID}" > /root/pgid

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
