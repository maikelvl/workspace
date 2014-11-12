FROM crobays/workspace-base
MAINTAINER Crobays <crobays@userex.nl>

ENV CONFIG_DIR /workspace/config
ENV SCRIPTS /workspace/config-scripts

VOLUME  ["/workspace"]

# Run entrypoint
ADD /config-scripts/run.sh /scripts/run.sh
RUN chmod +x /etc/my_init.d/* && chmod +x /scripts/run.sh

ENTRYPOINT ["/scripts/run.sh"]

# Clean up APT when done.
RUN apt-get clean && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
