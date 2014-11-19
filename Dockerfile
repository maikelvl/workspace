FROM phusion/baseimage:0.9.15
ENV HOME /root
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

MAINTAINER Crobays <crobays@userex.nl>
ENV DEBIAN_FRONTEND noninteractive
ENV TIMEZONE Etc/UTC
# Adding scripts in chunks so rebuilding doesn't take so long each time

# Update and server
ADD /scripts/core /scripts/core
RUN /scripts/core/update.sh
RUN /scripts/core/dist-upgrade.sh
RUN /scripts/core/build-essential.sh
RUN /scripts/core/linux-image-extra.sh

# Utilities
ADD /scripts/utilities /scripts/utilities

# Essential
ADD /scripts/essential /scripts/essential
RUN /scripts/essential/curl.sh
RUN /scripts/essential/vim.sh
RUN /scripts/essential/rvm-ruby.sh stable
RUN /scripts/essential/node.sh
RUN /scripts/essential/bundler.sh
RUN /scripts/essential/php.sh
RUN /scripts/essential/pip.sh

# Git
ADD /scripts/git /scripts/git
RUN /scripts/git/git.sh 2.1

# Terminal
ADD /scripts/terminal /scripts/terminal
RUN /scripts/terminal/zsh.sh

# Docker
ADD /scripts/docker /scripts/docker
RUN /scripts/docker/docker.sh
RUN /scripts/docker/fig.sh
RUN /scripts/docker/maestro-ng.sh

# Provider
ADD /scripts/provider /scripts/provider
RUN /scripts/provider/terraform.sh
RUN /scripts/provider/dot.sh
RUN /scripts/provider/packer.sh
RUN /scripts/provider/tugboat.sh

# other
ADD /scripts/other /scripts/other
RUN /scripts/other/tree.sh
RUN /scripts/other/bower.sh
RUN /scripts/other/composer.sh
RUN /scripts/other/laravel-installer.sh

RUN rm -rf /downloads

# Add set timezone
RUN echo "#!/bin/bash\necho \"\$TIMEZONE\" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata" > /etc/my_init.d/01-timezone.sh

ENV CONFIG_DIR /workspace/config

VOLUME  ["/workspace"]

# Run entrypoint
ADD /scripts/config /scripts/config
RUN chmod +x /etc/my_init.d/*

RUN echo "#!/bin/bash\nif [ -f /workspace/scripts/config/run.sh ]\nthen\n\t/workspace/scripts/config/run.sh\nelse\n\t/scripts/config/run.sh\nfi" > /root/run.sh && \
	chmod +x /root/run.sh

ENTRYPOINT ["/root/run.sh"]

# Clean up APT when done.
RUN apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# docker build -t workspace-base-test /workspace/base && \
# docker run -it --rm -v /workspace:/workspace workspace-base-test bash
