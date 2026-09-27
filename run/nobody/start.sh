#!/usr/bin/dumb-init /bin/bash

set -x
# set install location for crafty
crafty_install_path="/opt/crafty"

crafty_config_path="/config/crafty"

# crafty lock file (indicates crafty process running) path, deleted on startup (process not running)
crafty_session_lock_filepath="${crafty_config_path}/app/config/session.lock"

cd "${crafty_install_path}" || { echo '[ERROR] Could not change directory to crafty install path'; exit 1; }

# create paths if they dont exist
mkdir -p \
	"${crafty_config_path}/app/config" \
	"${crafty_config_path}/logs" \
	"${crafty_config_path}/import" \
	"${crafty_config_path}/servers" \
	"${crafty_config_path}/backups" \
	|| { echo '[ERROR] Could not create crafty config paths'; exit 1; }

# symlink app to config
source 'utils.sh' && symlink --src-path "${crafty_config_path}/app/config" --dst-path "${crafty_install_path}/app/config" --link-type 'softlink'

# symlink logs to config
source 'utils.sh' && symlink --src-path "${crafty_config_path}/logs" --dst-path "${crafty_install_path}/logs" --link-type 'softlink'

# symlink import to config
source 'utils.sh' && symlink --src-path "${crafty_config_path}/import" --dst-path "${crafty_install_path}/import" --link-type 'softlink'

# symlink servers to config
source 'utils.sh' && symlink --src-path "${crafty_config_path}/servers" --dst-path "${crafty_install_path}/servers" --link-type 'softlink'

# symlink backups to config
source 'utils.sh' && symlink --src-path "${crafty_config_path}/backups" --dst-path "${crafty_install_path}/backups" --link-type 'softlink'

# if any default config files are missing (no clobber) then copy from 'config-backup' folder (created by utils.sh symlink)
cp -n -R "${crafty_install_path}/app/config-backup/"* "${crafty_install_path}/app/config/"

# activate virtualenv where requirements have been installed from install.sh
source "${crafty_install_path}/venv/bin/activate"

# remove previous session lock file if it exists (contains pid and datetime)
if [[ -f "${crafty_session_lock_filepath}" ]]; then
	echo "Removing previous session.lock file '${crafty_session_lock_filepath}'..."
	rm -f "${crafty_session_lock_filepath}"
fi

# overwrite file containing latest version info
cp "${crafty_install_path}/app/config-backup/version.json" "${crafty_config_path}/app/config/version.json"

# run app
python3 "${crafty_install_path}/main.py"
