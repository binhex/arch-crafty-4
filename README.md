**Application**

[Siphonator](https://github.com/binhex/siphonator)

**Description**

Siphonator is a command line tool written in Python, designed to streamline the process of discovering and acquiring movies based on precise user-defined criteria, leveraging the extensive IMDb database. Users can construct complex filters to pinpoint films matching their specific preferences, automating the download process through integration with a torrent client.

**Build notes**

Latest commit to GitHub branch 'master'.

**Usage**
```
docker run -d \
    --name=<container name> \
    -v <path for config files>:/config \
    -v <path for media files>:/media \
    -v <path for data files>:/data \
    -v /etc/localtime:/etc/localtime:ro \
    -e TZ=Etc/<region> \
    -e UMASK=<umask for created files> \
    -e PUID=<uid for user> \
    -e PGID=<gid for user> \
    binhex/arch-siphonator
```

Please replace all user variables in the above command defined by <> with the correct values.

**Example**
```
docker run -d \
    --name=siphonator \
    -v /media/tv:/media \
    -v /apps/docker/deluge/data:/data \
    -v /apps/docker/deluge/config:/config \
    -v /etc/localtime:/etc/localtime:ro \
    -e TZ=Etc/UTC \
    -e UMASK=000 \
    -e PUID=99 \
    -e PGID=100 \
    binhex/arch-siphonator
```

**Notes**

User ID (PUID) and Group ID (PGID) can be found by issuing the following command for the user you want to run the container as:-

```
id <username>
```
___
If you appreciate my work, then please consider buying me a beer  :D

[![PayPal donation](https://www.paypal.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=MM5E27UX6AUU4)

[Documentation](https://github.com/binhex/documentation) | [Support forum](https://forums.unraid.net/topic/)