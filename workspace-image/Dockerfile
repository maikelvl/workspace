FROM phusion/baseimage:0.9.16
ENV HOME /root
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

MAINTAINER Crobays <crobays@userex.nl>
ENV DEBIAN_FRONTEND noninteractive
ENV TIMEZONE Etc/UTC
# Adding scripts in chunks so rebuilding doesn't take so long each time

# Update and server
ADD /core /scripts/core
RUN /scripts/core/update.sh && \
	/scripts/core/dist-upgrade.sh && \
	/scripts/core/build-essential.sh && \
	/scripts/core/linux-image-extra.sh

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
RUN /scripts/git/git.sh 2

# Terminal
ADD /terminal /scripts/terminal
RUN /scripts/terminal/zsh.sh

# Docker
ADD /docker /scripts/docker
RUN /scripts/docker/docker.sh && \
	/scripts/docker/fig.sh && \
	/scripts/docker/maestro-ng.sh

# Provider
ADD /provider /scripts/provider
RUN /scripts/provider/terraform.sh && \
	/scripts/provider/dot.sh && \
	/scripts/provider/packer.sh && \
	/scripts/provider/tugboat.sh

# other
ADD /other /scripts/other
RUN /scripts/other/tree.sh && \
	/scripts/other/bower.sh && \
	/scripts/other/ember-cli.sh && \
	/scripts/other/composer.sh && \
	/scripts/other/laravel-installer.sh

ENV CONFIG_DIR /workspace/config

VOLUME /workspace
WORKDIR /workspace

# Run entrypoint
ADD /config-scripts /scripts/config-scripts
ADD /run.sh /root/run.sh

# Add config boilerplate
ADD /config-boilerplate /root/config-boilerplate

# Add set timezone
RUN echo "#!/bin/bash\nif [ ! -f /etc/timezone ] || [ \"\$(cat /etc/timezone)\" != \"\$TIMEZONE\" ]\nthen\n\techo \"\$TIMEZONE\" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata\nfi" > /etc/my_init.d/01-timezone.sh && \
	echo "#!/bin/bash\nif [ -f /workspace/workspace-image/run.sh ]\nthen\n\t/workspace/workspace-image/run.sh\nelse\n\t/root/run.sh\nfi" > /root/start && \
	chmod +x /etc/my_init.d/* && \
	chmod +x /root/start && \
	apt-get clean && \
	rm -rf /downloads /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENTRYPOINT ["/root/start"]

# docker build -t workspace-base-test /workspace/base && \
# docker run -it --rm -v /workspace:/workspace workspace-base-test bash
