FROM phusion/baseimage:0.9.17

MAINTAINER Crobays <crobays@userex.nl>

ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV TIMEZONE Etc/UTC
ENV CONFIG_DIR /workspace/config

RUN rm -rf /etc/service/sshd/down
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh
RUN rm /etc/update-motd.d/*

VOLUME /workspace
WORKDIR /workspace

# Adding scripts in chunks so rebuilding doesn't take so long each time

# Update and server
ADD /core /scripts/core
RUN /scripts/core/update.sh && \
	/scripts/core/dist-upgrade.sh && \
	/scripts/core/build-essential.sh

# Utilities
ADD /utilities /scripts/utilities

# Essential
ADD /essential /scripts/essential
RUN /scripts/essential/curl.sh && \
	/scripts/essential/vim.sh && \
	/scripts/essential/rvm-ruby.sh stable && \
	/scripts/essential/node.sh && \
	/scripts/essential/bundler.sh && \
	/scripts/essential/php.sh && \
	/scripts/essential/pip.sh

# Git
ADD /git /scripts/git
RUN /scripts/git/git.sh

# Terminal
ADD /terminal /scripts/terminal
RUN /scripts/terminal/zsh.sh

# Docker
ADD /docker /scripts/docker
RUN /scripts/docker/docker.sh && \
	/scripts/docker/docker-compose.sh

# Provider
# ADD /provider /scripts/provider
# RUN /scripts/provider/terraform.sh && \
# 	/scripts/provider/dot.sh && \
# 	/scripts/provider/packer.sh && \
# 	/scripts/provider/tugboat.sh

# other
ADD /other /scripts/other
RUN /scripts/other/bower.sh && \
	/scripts/other/dot-json.sh && \
	/scripts/other/ember-cli.sh && \
	/scripts/other/fabric.sh && \
	/scripts/other/travis-cli.sh && \
	/scripts/other/tree.sh

# Run entrypoint
ADD /config-scripts /scripts/config-scripts

# Add config boilerplate
ADD /config-boilerplate /root/config-boilerplate

# Add set timezone
RUN echo "#!/bin/bash\necho \"Timezone: \$TIMEZONE\"\nif [ ! -f /etc/timezone ] || [ \"\$(cat /etc/timezone)\" != \"\$TIMEZONE\" ]\nthen\n\techo \"\$TIMEZONE\" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata\nfi" > /etc/my_init.d/01-timezone.sh
ADD /run.sh /etc/my_init.d/02-config-user.sh

RUN chmod +x /etc/my_init.d/*

RUN apt-get clean && rm -rf /downloads /var/lib/apt/lists/* /tmp/* /var/tmp/*

EXPOSE 22

CMD ["/sbin/my_init"]

# docker build -t workspace-base-test /workspace/base && \
# docker run -it --rm -v /workspace:/workspace workspace-base-test bash
