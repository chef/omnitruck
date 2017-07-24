#!/bin/sh
build && \
build habitat/omnitruck-web-proxy && \
build habitat/omnitruck-poller && \
build habitat/omnitruck-web && \
hab start $HAB_ORIGIN/omnitruck && \
hab start $HAB_ORIGIN/omnitruck-web-proxy && \
hab start $HAB_ORIGIN/omnitruck-poller && \
hab start $HAB_ORIGIN/omnitruck-web
