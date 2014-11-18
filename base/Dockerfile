FROM phusion/baseimage:0.9.15
ENV HOME /root
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

MAINTAINER Crobays <crobays@userex.nl>
ENV DEBIAN_FRONTEND noninteractive
ENV TIMEZONE Etc/UTC
# Adding scripts in chunks so rebuilding doesn't take so long each time

# Update and server
ADD /core /scripts/core
RUN /scripts/core/update.sh
RUN /scripts/core/dist-upgrade.sh
RUN /scripts/core/build-essential.sh
RUN /scripts/core/linux-image-extra.sh

# Utilities
ADD /utilities /scripts/utilities

# Essential
ADD /essential /scripts/essential
RUN /scripts/essential/curl.sh
RUN /scripts/essential/vim.sh
RUN /scripts/essential/rvm-ruby.sh stable 2.1
RUN /scripts/essential/node.sh
RUN /scripts/essential/bundler.sh
RUN /scripts/essential/php.sh
RUN /scripts/essential/pip.sh

# Git
ADD /git /scripts/git
RUN /scripts/git/git.sh 2.1

# Terminal
ADD /terminal /scripts/terminal
RUN /scripts/terminal/zsh.sh 5.0.7

# Docker
ADD /docker /scripts/docker
RUN /scripts/docker/docker.sh
RUN /scripts/docker/fig.sh
RUN /scripts/docker/maestro-ng.sh

# Provider
ADD /provider /scripts/provider
RUN /scripts/provider/terraform.sh 0.3.0
RUN /scripts/provider/dot.sh
RUN /scripts/provider/packer.sh 0.7.1
RUN /scripts/provider/tugboat.sh

# other
ADD /other /scripts/other
RUN /scripts/other/tree.sh
RUN /scripts/other/bower.sh
RUN /scripts/other/composer.sh
RUN /scripts/other/laravel-installer.sh

# Add set timezone
RUN echo "#!/bin/bash\necho \"\$TIMEZONE\" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata" > /etc/my_init.d/01-timezone.sh

# Run entrypoint
ADD /run.sh /scripts/run.sh
RUN chmod +x /etc/my_init.d/* && chmod +x /scripts/run.sh

ENTRYPOINT ["/scripts/run.sh"]

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
