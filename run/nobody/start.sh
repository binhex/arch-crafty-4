#!/usr/bin/dumb-init /bin/bash

# set install location for crafty
siphonator_install_path="/opt/siphonator"

# set path to store configuration files
config_path="/config/siphonator"

# activate virtualenv where requirements have been installed from install.sh
source "${siphonator_install_path}/venv/bin/activate"

# run app
python3 "${siphonator_install_path}/siphonator.py" \
  --log-path "${config_path}/logs" \
  --pid-path "${config_path}/pids" \
  --config-path "${config_path}/configs" \
  --db-path "${config_path}/db"
