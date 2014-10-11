FROM crobays/workspace-base
MAINTAINER Crobays <crobays@userex.nl>

ENV CONFIG_DIR /workspace/config
ENV SCRIPTS /workspace/config-scripts

VOLUME  ["/workspace"]

ADD /config-scripts/run.sh /scripts/run.sh
RUN chmod +x /scripts/run.sh

ENTRYPOINT ["/scripts/run.sh"]
