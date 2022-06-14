#!/bin/bash

crafty_install_path="/opt/crafty"

mkdir -p '/config/crafty/db' '/config/crafty/config' '/config/crafty/servers'

config_filepath='/config/crafty/config/docker_config.yml'

# copy example config file
if [ ! -f "${config_filepath}" ]; then
	cp "${crafty_install_path}/configs/docker_config.yml" "${config_filepath}"
fi

# modify config file
###

# tells crafty if it should activate the console and not loop forever
#sed -i -E "s~daemon_mode: true~daemon_mode: false~g" "${config_filepath}"

# tells crafty where to store the database it creates
sed -i -E 's~db_dir: "/crafty_db"~db_dir: "/config/crafty/db"~g' "${config_filepath}"

# symlink certs to config
source '/usr/local/bin/utils.sh' && symlink --src-path "${crafty_install_path}/app/web/certs" --dst-path '/config/crafty/certs' --link-type 'softlink' --log-level 'WARN'

# symlink backups to config
source '/usr/local/bin/utils.sh' && symlink --src-path "${crafty_install_path}/backups" --dst-path '/config/crafty/backups' --link-type 'softlink' --log-level 'WARN'

# change to app install path and activate virtualenv
cd "${crafty_install_path}"

# activate virtualenv where requirements have been installed from install.sh
source ./env/bin/activate

# run app
python3 "${crafty_install_path}/crafty.py" --config "${config_filepath}"
