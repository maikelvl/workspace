FROM alpine:3.10

RUN apk add --no-cache \
        apache2-utils \
        autoconf \
        automake \
        bash \
        bind-tools \
        build-base \
        file \
        file \
        git \
        git-email \
        git-perl \
        gnupg \
        go \
        grep \
        iproute2 \
        jpeg-dev \
        less \
        libc-dev \
        libffi-dev \
        libtool \
        linux-headers \
        make \
        moreutils \
        ncurses \
        nodejs \
        openssh \
        openssl-dev \
        perl \
        python3-dev \
        sudo \
        tree \
        tzdata \
        unzip \
        util-linux \
        vim \
        zip \
        zlib-dev \
        zsh \
 && ln -sf python3 /usr/bin/python \
 && ln -sf $(ls /usr/lib | grep ^python | head -n 1) /usr/lib/python \
 && rm -rf \
        /usr/lib/**/*.pyc \
        /usr/lib/**/__pycache__ \
 && wget -O /usr/local/bin/jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 \
 && chmod +x /usr/local/bin/jq \
 && wget -O j2y.zip https://github.com/y13i/j2y/releases/download/v0.0.7/j2y-linux_amd64.zip \
 && unzip j2y.zip \
 && rm j2y.zip \
 && mv j2y /usr/local/bin/j2y

ENV PATH="/usr/local/node/bin:$PATH" \
    NGHTTP2_VERSION="1.39.1" \
    CURL_VERSION="7.65.1"

RUN cd /tmp \
 && wget https://github.com/nghttp2/nghttp2/releases/download/v${NGHTTP2_VERSION}/nghttp2-${NGHTTP2_VERSION}.tar.bz2 \
 && wget https://dl.uxnr.de/mirror/curl/curl-${CURL_VERSION}.tar.bz2 \
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
 && export GOPATH=/tmp/go-workspace \
 && mkdir -pv ${GOPATH} \
 && go get github.com/fatih/color \
 && go get github.com/google/go-jsonnet \
 && cd ${GOPATH}/src/github.com/google/go-jsonnet \
 && go build ./cmd/jsonnet \
 && mv ./jsonnet /usr/local/bin/jsonnet \
 && jsonnet --version \
 && go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb \
 && mv ${GOPATH}/bin/jb /usr/local/bin/ \
 && jb --help \
 && go get github.com/brancz/gojsontoyaml \
 && mv ${GOPATH}/bin/gojsontoyaml /usr/local/bin/ \
 && echo '{"test": "hello world"}' | gojsontoyaml \
 && go get github.com/kubernetes/kompose \
 && mv ${GOPATH}/bin/kompose /usr/local/bin/kompose \
 && kompose version \
 && ks_version=0.13.1 \
 && cd /tmp \
 && curl \
        --fail \
        --location \
        --url https://github.com/ksonnet/ksonnet/releases/download/v${ks_version}/ks_${ks_version}_linux_amd64.tar.gz \
        --output ks.tar.gz \
 && tar -zxf ks.tar.gz \
 && mv ks_${ks_version}_linux_amd64/ks /usr/local/bin/ks \
 && ks version \
 && krew_version=0.3.4 \
 && cd /tmp \
 && curl \
        --fail \
        --location \
        --url https://github.com/kubernetes-sigs/krew/releases/download/v${krew_version}/krew.tar.gz \
        --output krew.tar.gz \
 && tar -zxf krew.tar.gz \
 && mv krew-$(uname | tr '[:upper:]' '[:lower:]')_amd64 /usr/local/bin/kubectl-krew \
 && kubectl-krew version \
 && rm -rf /root/.krew \
 && curl \
        --fail \
        --location \
        --url https://github.com/gliderlabs/sigil/releases/download/v0.4.0/sigil_0.4.0_Linux_x86_64.tgz | tar -zxC /usr/local/bin \
 && rm -rf /tmp/*

# RUN version="$(curl --url https://github.com/git-lfs/git-lfs/releases/latest -I -s | grep -i 'location:' | head -n 1 | sed -En 's|.*tag/v([0-9\.]+).*|\1|p')" \
RUN version=2.7.2 \
 && cd /tmp \
 && curl \
        --fail \
        --location \
        --url https://github.com/git-lfs/git-lfs/releases/download/v${version}/git-lfs-linux-amd64-v${version}.tar.gz \
        --output git-lfs.tar.gz \
 && tar -zxf git-lfs.tar.gz \
 && mv /tmp/git-lfs /usr/local/bin/git-lfs \
 && rm -rf /tmp/* \
 && [ $(stat -c %s /usr/local/bin/git-lfs) -gt 500 ] || exit 1

RUN wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/local/bin/cfssl \
 && wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/local/bin/cfssljson \
 && chmod +x /usr/local/bin/cfssl*

# RUN version="$(curl --url https://github.com/docker/machine/releases/latest | sed -rn 's/.*tag\/([^\"]*).*/\1/p')" \
RUN version=0.16.1 \
 && curl \
        --fail \
        --location \
        --url https://github.com/docker/machine/releases/download/v${version}/docker-machine-$(uname -s)-$(uname -m) \
        --output /usr/local/bin/docker-machine \
 && chmod +x /usr/local/bin/docker-machine \
 && [ $(stat -c %s /usr/local/bin/docker-machine) -gt 500 ] || exit 1

COPY bin/install-docker /usr/local/bin/install-docker
RUN install-docker 18.06.3-ce

COPY compose.patch /tmp/compose.patch
RUN cd /tmp \
 && git clone https://github.com/pypa/pip.git -b 19.1.1 \
 && cd pip \
 && python setup.py install \
 && pip install --no-cache-dir \
        awscli==1.16.180 \
        cookiecutter==1.6.0 \
        docker-compose==1.24.0 \
        ipdb==0.11 \
        json2yaml==1.1.1 \
        pillow==7.1.2 \
        prompt==0.4.1 \
 && mv $(which yaml2json) $(dirname $(which yaml2json))/pyyaml2json \
 && mv $(which json2yaml) $(dirname $(which json2yaml))/pyjson2yaml \
 && version=1.2 \
 && wget -O /usr/bin/yaml2json https://github.com/bronze1man/yaml2json/releases/download/v${version}/yaml2json_linux_amd64 \
 && chmod +x /usr/bin/yaml2json \
 && cd /usr/lib/python/site-packages/compose \
 && git apply /tmp/compose.patch \
 && docker-compose --version \
 && rm -rf \
        /tmp/* \
        /usr/lib/**/*.pyc \
        /usr/lib/**/__pycache__

RUN rm /etc/motd \
 && passwd root -d "$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)" \
 && ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N "" -t rsa \
 && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N "" -t dsa \
 && ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N "" -t ecdsa \
 && ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N "" -t ed25519 \
 && curl \
        --fail \
        --location \
        --url https://github.com/ohmyzsh/ohmyzsh/archive/17428f3.zip \
        --output /tmp/ohmyzsh.zip \
 && unzip /tmp/ohmyzsh.zip -d /var/lib \
 && mv /var/lib/ohmyzsh* /var/lib/oh-my-zsh \
 && ln -sf ~/theme.zsh-theme /var/lib/oh-my-zsh/home.zsh-theme \
 && rm -rf /tmp/*

RUN git clone https://github.com/tj/git-extras.git -b 4.7.0 \
 && cd git-extras \
 && make install \
 && cp -f man/git-*.1 /usr/local/share/man/man1 \
 && cp -f etc/git-extras-completion.zsh /var/lib/oh-my-zsh/plugins/git-extras/git-extras.plugin.zsh \
 && rm -rf ../git-extras

RUN wget https://dl.min.io/client/mc/release/linux-amd64/archive/mc.RELEASE.2020-06-16T19-24-41Z -O /usr/local/bin/mc \
 && sha256sum /usr/local/bin/mc \
 && echo "ff246d5ffc91d7318b2b56e5bc4bbd20c4efc4ed52a3efb974e54bb56f4f1ce5  /usr/local/bin/mc" | sha256sum -c \
 && chmod +x /usr/local/bin/mc \
 && mc --version

# https://cloud.google.com/sdk/docs/release-notes
ENV GCLOUD_VERSION="299.0.0" \
    PATH="/usr/lib/google-cloud-sdk/bin:${PATH}"
COPY bin/install-gcloud /usr/local/bin/
RUN install-gcloud $GCLOUD_VERSION \
 && gcloud config set component_manager/disable_update_check true

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
