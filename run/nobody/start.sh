#!/usr/bin/dumb-init /bin/bash

set -x
# set install location for crafty
crafty_install_path="/opt/crafty"

crafty_session_lock_filepath="/config/crafty/app/config/session.lock"

# symlink app to config
source '/usr/local/bin/utils.sh' && symlink --src-path "${crafty_install_path}/app/config" --dst-path '/config/crafty/app/config' --link-type 'softlink' --log-level 'WARN'

# symlink logs to config
source '/usr/local/bin/utils.sh' && symlink --src-path "${crafty_install_path}/logs" --dst-path '/config/crafty/logs' --link-type 'softlink' --log-level 'WARN'

# symlink import to config
source '/usr/local/bin/utils.sh' && symlink --src-path "${crafty_install_path}/import" --dst-path '/config/crafty/import' --link-type 'softlink' --log-level 'WARN'

# symlink servers to config
source '/usr/local/bin/utils.sh' && symlink --src-path "${crafty_install_path}/servers" --dst-path '/config/crafty/servers' --link-type 'softlink' --log-level 'WARN'

# symlink backups to config
source '/usr/local/bin/utils.sh' && symlink --src-path "${crafty_install_path}/backups" --dst-path '/config/crafty/backups' --link-type 'softlink' --log-level 'WARN'

cd "${crafty_install_path}"

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
cp "${crafty_install_path}/app/config-backup/version.json" '/config/crafty/app/config/version.json'

# run app
python3 "${crafty_install_path}/main.py"
