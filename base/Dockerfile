FROM ubuntu:trusty
MAINTAINER Crobays <crobays@userex.nl>

ENV DEBIAN_FRONTEND noninteractive

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
RUN /scripts/essential/rvm-ruby.sh stable 2.1.3
RUN /scripts/essential/node.sh
RUN /scripts/essential/bundler.sh
RUN /scripts/essential/php.sh
RUN /scripts/essential/pip.sh

# Git
ADD /git /scripts/git
RUN /scripts/git/git.sh 2.1.1

# Terminal
ADD /terminal /scripts/terminal
RUN /scripts/terminal/zsh.sh 5.0.5

# Docker
ADD /docker /scripts/docker
RUN /scripts/docker/docker.sh
RUN /scripts/docker/fig.sh 0.5.2
RUN /scripts/docker/maestro-ng.sh

# Provider
ADD /provider /scripts/provider
RUN /scripts/provider/terraform.sh 0.2.2
RUN /scripts/provider/dot.sh
RUN /scripts/provider/packer.sh 0.7.1
RUN /scripts/provider/tugboat.sh

# other
ADD /other /scripts/other
RUN /scripts/other/tree.sh
RUN /scripts/other/bower.sh
RUN /scripts/other/composer.sh
RUN /scripts/other/laravel-installer.sh

# Run entrypoint
ADD /run.sh /scripts/run.sh
ENTRYPOINT ["/scripts/run.sh"]
