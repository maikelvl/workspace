FROM alpine:3.2

MAINTAINER Maikel Vlasman <open-source@userex.nl>

RUN echo '@edge http://nl.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories \
 && echo '@community http://nl.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories \
 && echo '@testing http://nl.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

RUN apk add --update \
		curl \
		git@edge \
		less \
		nodejs \
		openssh \
		perl \
		php-curl \
		php-json \
		php-openssl \
		php-phar \
		py-crypto \
		py-pip \
		ruby-bundler \
		sudo \
		tree \
		tzdata \
		unzip \
		vim \
		zsh \
 && rm -rf /var/cache/apk/*

ADD /DOCKER_VERSION /DOCKER_VERSION
ADD /install-scripts /scripts/install-scripts
RUN /scripts/install-scripts/docker.sh \
 && /scripts/install-scripts/git-perl.sh \
 && /scripts/install-scripts/php-composer.sh

ENV PATH /usr/local/node/bin:$PATH
RUN npm install -g \
		bower \
		ember-cli \
		dot-json

RUN pip install --no-cache-dir --upgrade --ignore-installed --force-reinstall pip \
 && pip install --no-cache-dir \
		docker-compose \
		fabric

RUN rm /etc/motd \
 && passwd root -d "$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)" \
 && ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N "" -t rsa \
 && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N "" -t dsa \
 && ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N "" -t ecdsa \
 && ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N "" -t ed25519 \
 && curl -L -o /tmp/oh-my-zsh.zip https://github.com/crobays/oh-my-zsh/archive/master.zip \
 && unzip /tmp/oh-my-zsh.zip -d /var/lib \
 && rm /tmp/oh-my-zsh.zip \
 && mv /var/lib/oh-my-zsh* /var/lib/oh-my-zsh

ENV USER=user \
	HOME=/workspace/home \
	EDITOR=vim \
	TIMEZONE=UTC \
	SSH_KEY=.ssh/workspace_rsa

EXPOSE 22
WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]

ADD home-template /tmp/home-template
ADD entrypoint.sh /entrypoint.sh

RUN date +%s > /.build-time
