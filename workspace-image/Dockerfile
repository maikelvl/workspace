FROM phusion/baseimage:0.9.17

MAINTAINER Maikel Vlasman <open-source@userex.nl>

ENV HOME=/root \
	DEBIAN_FRONTEND=noninteractive \
	TIMEZONE=Etc/UTC \
	CONFIG_DIR=/workspace/config

RUN rm -rf /etc/service/sshd/down && \
	/etc/my_init.d/00_regen_ssh_host_keys.sh && \
	rm /etc/update-motd.d/*

WORKDIR /workspace

RUN add-apt-repository -y ppa:git-core/ppa && \
	add-apt-repository -y ppa:ondrej/php5 && \
	apt-get update

RUN apt-get install -y \
		build-essential \
		software-properties-common \
		python-software-properties \
		gcc \
		make \
		autoconf \
		yodl \
		libncursesw5-dev \
		texinfo \
		checkinstall

RUN apt-get install -y \
		curl \
		dnsutils \
		git \
		ruby-bundler \
		tree \
		vim \
		zsh

ADD /install-scripts /scripts/install-scripts
RUN /scripts/install-scripts/node.sh && \
	/scripts/install-scripts/php.sh && \
	/scripts/install-scripts/php-composer.sh && \
	/scripts/install-scripts/pip.sh && \
	/scripts/install-scripts/rvm-ruby.sh stable && \
	/scripts/install-scripts/docker.sh
	
ENV PATH /usr/local/node/bin:$PATH
RUN npm install -g \
		bower \
		ember-cli \
		dot-json
RUN pip install \
		docker-compose \
		fabric

RUN apt-get clean && \
	rm -rf /downloads /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Add config scripts
ADD /config-scripts /scripts/config-scripts

# Add config boilerplate
ADD /config-boilerplate /root/config-boilerplate

# Add set timezone
RUN echo "#!/bin/bash\necho \"Timezone: \$TIMEZONE\"\nif [ ! -f /etc/timezone ] || [ \"\$(cat /etc/timezone)\" != \"\$TIMEZONE\" ]\nthen\n\techo \"\$TIMEZONE\" > /etc/timezone && dpkg-reconfigure -f noninteractive tzdata\nfi" > /etc/my_init.d/01-timezone.sh
ADD /bootstrap.sh /etc/my_init.d/02-bootstrap.sh

RUN chmod +x /etc/my_init.d/*

EXPOSE 22

CMD ["/sbin/my_init"]
