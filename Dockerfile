FROM crobays/workspace-base
MAINTAINER Crobays <crobays@userex.nl>

ENV CONFIG_DIR /workspace/config
ENV SCRIPTS /workspace/config-scripts

VOLUME  ["/workspace"]

ENTRYPOINT ["/workspace/config-scripts/run.sh"]
