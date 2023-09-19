FROM binhex/arch-base:latest
LABEL org.opencontainers.image.authors = "binhex"
LABEL org.opencontainers.image.source = "https://github.com/binhex/arch-crafty-4"

# additional files
##################

# add supervisor conf file for app
ADD build/*.conf /etc/supervisor/conf.d/

# add install bash script
ADD build/root/*.sh /root/

# get release tag name from build arg
arg RELEASETAG

# add run bash script
ADD run/nobody/*.sh /home/nobody/

# install app
#############

# make executable and run bash scripts to install app
RUN chmod +x /root/*.sh && \
	/bin/bash /root/install.sh "${release_tag_name}"

# docker settings
#################

# expose ipv4 port range for minecraft bedrock servers
EXPOSE 19132-19232/tcp
EXPOSE 19132-19232/udp

# expose ipv4 port range for minecraft java servers
EXPOSE 25565-25575

# expose ipv4 port for crafty web ui http (redirects to https)
EXPOSE 8000

# expose ipv4 port for crafty web ui https
EXPOSE 8443

# Security Patch for CVE-2021-44228
ENV LOG4J_FORMAT_MSG_NO_LOOKUPS=true

# set permissions
#################

# run script to set uid, gid and permissions
CMD ["/bin/bash", "/usr/local/bin/init.sh"]