FROM alpine:3.4

MAINTAINER Maikel Vlasman <open-source@userex.nl>

RUN apk --no-cache add \
        apache2-utils \
        bash \
        bind-tools \
        file \
        git \
        grep \
        less \
        make \
        nodejs \
        openssh \
        openssl \
        perl \
        python3-dev \
        sudo \
        tree \
        tzdata \
        unzip \
        vim \
        zip \
        zsh \
 && ln -sf python3 /usr/bin/python \
 && rm -rf \
        /usr/lib/**/*.pyc \
        /usr/lib/**/__pycache__ \
 && wget -O /usr/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 \
 && chmod +x /usr/bin/jq \
 && wget -O j2y.zip https://github.com/y13i/j2y/releases/download/v0.0.7/j2y-linux_amd64.zip \
 && unzip j2y.zip \
 && rm j2y.zip \
 && mv j2y /usr/bin/j2y

ENV PATH="/usr/local/node/bin:$PATH" \
    NGHTTP2_VERSION="1.10.0" \
    CURL_VERSION="7.49.0"

RUN cd /tmp \
 && wget https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.bz2 \
 && wget https://dl.uxnr.de/mirror/curl/curl-${CURL_VERSION}.tar.bz2 \
 && apk add --no-cache --virtual build-packages \
        autoconf \
        automake \
        build-base \
        file \
        libtool \
        openssl-dev \
 && tar -xvjf nghttp2-${NGHTTP2_VERSION}.tar.bz2 \
 && cd /tmp/nghttp2-${NGHTTP2_VERSION} \
 && autoreconf -i \
 && automake \
 && autoconf \
 && ./configure \
 && make \
 && make install \
 && cd /tmp \
 && tar -xvjf curl-${CURL_VERSION}.tar.bz2 \
 && cd /tmp/curl-${CURL_VERSION} \
 && ./configure \
        --with-nghttp2=/usr/local \
        --with-ssl \
 && make \
 && make install \
 && apk del build-packages \
 && rm -rf /tmp/*

RUN git_version=$(git --version | sed -rn "s/.*(\d+\.\d+\.\d+).*/\1/p") \
 && cd /tmp \
 && curl \
        --location \
        --url https://github.com/git/git/archive/v$git_version.zip \
        --output git.zip \
 && unzip -d git git.zip \
 && mkdir -p /usr/share/perl5/site_perl \
 && mv git/$(ls git)/perl/* /usr/share/perl5/site_perl/ \
 && rm -rf git git.zip /usr/share/perl5/site_perl/Makefile* \
 && cp /usr/share/perl5/site_perl/private-Error.pm /usr/share/perl5/site_perl/Error.pm

RUN wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/bin/cfssl \
 && wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/bin/cfssljson \
 && chmod +x /usr/bin/cfssl*

RUN latest="$(curl --url https://github.com/docker/machine/releases/latest | sed -rn 's/.*tag\/([^\"]*).*/\1/p')" \
 && echo "latest: $latest" \
 && curl \
        --location \
        --url https://github.com/docker/machine/releases/download/$latest/docker-machine-$(uname -s)-$(uname -m) \
        --output /usr/bin/docker-machine \
 && chmod +x /usr/bin/docker-machine \
 && [ $(stat -c %s /usr/bin/docker-machine) -gt 500 ] || exit 1

COPY bin/install-docker /usr/local/bin/install-docker
RUN install-docker 1.12.6
RUN install-docker 1.13.1
RUN install-docker 17.03.1-ce
RUN install-docker 17.04.0-ce

RUN curl --location https://bootstrap.pypa.io/get-pip.py | python \
 && pip install --no-cache-dir --upgrade --ignore-installed --force-reinstall pip \
 && pip install --no-cache-dir \
        awscli \
        cookiecutter \
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

RUN git clone https://github.com/tj/git-extras.git -b 4.2.0 \
 && cd git-extras \
 && make install \
 && cp -f man/git-*.1 /usr/local/share/man/man1 \
 && cp -f etc/git-extras-completion.zsh /var/lib/oh-my-zsh/plugins/git-extras/git-extras.plugin.zsh \
 && rm -rf ../git-extras

RUN echo 'AcceptEnv TERM_PROGRAM' >> /etc/ssh/sshd_config \
 && echo 'AcceptEnv TERM_PROGRAM_VERSION' >> /etc/ssh/sshd_config \
 && echo 'AcceptEnv TERM_SESSION_ID' >> /etc/ssh/sshd_config

ENV USER="user" \
    EDITOR="vim" \
    TIMEZONE="UTC"

EXPOSE 22

COPY home-template /tmp/home-template
COPY home-workspace-template /tmp/home-workspace-template
COPY autoenv-activate.sh /usr/local/opt/autoenv/activate.sh
COPY bin/* /usr/local/bin/
COPY entrypoint.sh /

RUN date +%s > /.build-time

ENTRYPOINT ["/entrypoint.sh"]
CMD ["start"]
