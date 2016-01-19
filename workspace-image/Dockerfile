FROM alpine:3.3

MAINTAINER Maikel Vlasman <open-source@userex.nl>

RUN echo '@edge http://nl.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories \
 && echo '@community http://nl.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories \
 && echo '@testing http://nl.alpinelinux.org/alpine/edge/testing' >> /etc/apk/repositories

RUN apk add --update \
		curl \
		git \
		jq \
		less \
		nodejs \
		openssh \
		perl \
		python3-dev \
		sudo \
		tree \
		tzdata \
		unzip \
		vim \
		zsh \
 && rm -rf /var/cache/apk/* \
 && ln -sf python3 /usr/bin/python

ENV PATH /usr/local/node/bin:$PATH

RUN git_version=$(git --version | sed -rn "s/.*(\d+\.\d+\.\d+).*/\1/p") \
 && curl \
    --location \
    --url https://github.com/git/git/archive/v$git_version.zip \
    --output /tmp/git.zip \
&& unzip -d /tmp/git /tmp/git.zip \
&& mkdir -p /usr/share/perl5/site_perl \
&& mv /tmp/git/$(ls /tmp/git)/perl/* /usr/share/perl5/site_perl/ \
&& rm -rf /tmp/git /tmp/git.zip /usr/share/perl5/site_perl/Makefile* \
&& cp /usr/share/perl5/site_perl/private-Error.pm /usr/share/perl5/site_perl/Error.pm

RUN latest="$(curl --url https://github.com/docker/machine/releases/latest | sed -rn 's/.*tag\/([^\"]*).*/\1/p')" \
 && echo $latest \
 && curl \
 		--location \
		--url https://github.com/docker/machine/releases/download/$latest/docker-machine_linux-amd64 \
		--output /usr/bin/docker-machine \
 && chmod +x /usr/bin/docker-machine

COPY /install-docker /usr/bin/install-docker
RUN install-docker 1.7.1
RUN install-docker 1.8.3
RUN install-docker 1.9.1

RUN curl --location https://bootstrap.pypa.io/get-pip.py | python \
 && pip install --no-cache-dir --upgrade --ignore-installed --force-reinstall pip \
 && pip install --no-cache-dir \
 		docker-compose

RUN rm /etc/motd \
 && passwd root -d "$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)" \
 && ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N "" -t rsa \
 && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N "" -t dsa \
 && ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N "" -t ecdsa \
 && ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N "" -t ed25519 \
 && curl --location --url https://github.com/robbyrussell/oh-my-zsh/archive/master.zip --output /tmp/oh-my-zsh.zip \
 && unzip /tmp/oh-my-zsh.zip -d /var/lib \
 && rm /tmp/oh-my-zsh.zip \
 && mv /var/lib/oh-my-zsh* /var/lib/oh-my-zsh \
 && ln -sf ~/theme.zsh-theme /var/lib/oh-my-zsh/home.zsh-theme

ENV USER=user \
	EDITOR=vim \
	TIMEZONE=UTC \
	SSH_KEY=.ssh/workspace_rsa

EXPOSE 22
ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]

COPY home-template /tmp/home-template
COPY home-workspace-template /tmp/home-workspace-template
COPY /get-docker-server-version /usr/bin/get-docker-server-version
COPY /set-docker-client-version /usr/bin/set-docker-client-version
COPY entrypoint.sh /

RUN date +%s > /.build-time
