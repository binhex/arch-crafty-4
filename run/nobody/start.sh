#!/bin/bash

# set install location for crafty
crafty_install_path="/opt/crafty"

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

# if any default config files are missing (no clobber) then copy from 'config-backup' folder (created by utils.sh symlink)
cp -n -R '/opt/crafty/app/config-backup/'* '/opt/crafty/app/config/'

# activate virtualenv where requirements have been installed from install.sh
source ./env/bin/activate

# run app
python3 "${crafty_install_path}/main.py"
