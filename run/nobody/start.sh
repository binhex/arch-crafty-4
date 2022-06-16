#!/bin/bash

crafty_install_path="/opt/crafty"

mkdir -p '/config/crafty/app/config' '/config/crafty/logs' '/config/crafty/import' '/config/crafty/servers' '/config/crafty/backups'

config_filepath='/config/crafty/config/docker_config.yml'

# copy example config file
if [ ! -f "${config_filepath}" ]; then
	cp "${crafty_install_path}/configs/docker_config.yml" "${config_filepath}"
fi

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

# change to app install path and activate virtualenv
cd "${crafty_install_path}"

# activate virtualenv where requirements have been installed from install.sh
source ./env/bin/activate

# run app
python3 "${crafty_install_path}/main.py"
