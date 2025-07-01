# Application

[Crafty Controller v4](https://craftycontrol.com/)

## Description

Crafty Controller is a free and open-source Minecraft launcher and manager that
allows users to start and administer Minecraft servers from a user-friendly
interface. The interface is run as a self-hosted web server that is accessible
to devices on the local network by default and can be port forwarded to provide
external access outside of your local network. Crafty is designed to be easy to
install and use, requiring only a bit of technical knowledge and a desire to
learn to get started. Crafty Controller is still actively being developed by
Arcadia Technology and we are continually making major improvements to the
software.

Crafty Controller is a feature rich panel that allows you to create and run
servers, manage players, run commands, change server settings, view and edit
server files, and make backups. With the help of Crafty Controller managing a
large number of Minecraft servers on separate versions is easy and intuitive to
do.

## Build notes

Latest commit to GitHub branch 'master'.

## Usage

```bash
docker run -d \

    -p <host port for crafty web ui http>:8000 \
    -p <host port for crafty web ui https>:8443 \
    -p <host tcp port range for minecraft bedrock servers>:19132-19232/tcp \
    -p <host udp port range for minecraft bedrock servers>:19132-19232/udp \
    -p <host tcp port range for minecraft java servers>:25565-25575/tcp \
    --name=<container name> \
    -v <path for config files>:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e TZ=Etc/<region> \
    -e JAVA_VERSION=<8|11|17|21|latest> \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \

    binhex/arch-crafty-4

```

Please replace all user variables in the above command defined by <> with the
correct values.

## Access Crafty Web UI

`https://<host ip>:8443`
**Note** HTTP running on port `8000` is legacy and will redirect to HTTPS on
port `8443`

## Web UI Credentials

Username: `admin`

Password: This is now dynamically generated, if not set then the password will
be stored in `/config/crafty/app/config/default-creds.txt`, for reference the
previously hardcoded password was `crafty`.

## Example

```bash
docker run -d \

    -p 8000:8000 \
    -p 8443:8443 \
    -p 19132-19232:19132-19232/tcp \
    -p 19132-19232:19132-19232/udp \
    -p 25565-25575:25565-25575/tcp \
    --name=crafty \
    -v /apps/docker/crafty:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e TZ=Etc/UTC \
    -e JAVA_VERSION=latest \
    -e UMASK=000 \
    -e PUID=99 \
    -e PGID=100 \

    binhex/arch-crafty-4

```

## Notes

Crafty v4 does **not** support running as user `root` group `root`, so please
ensure `PUID` and `PGID` are NOT set to `0`.

User ID (PUID) and Group ID (PGID) can be found by issuing the following command
for the user you want to run the container as:-

```bsh
id <username>

```

___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Documentation](https://github.com/binhex/documentation) | [Support forum](https://forums.unraid.net/topic/124948-support-binhex-crafty-4/)
