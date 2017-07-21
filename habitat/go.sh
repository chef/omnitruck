#!/bin/sh
build && \
build habitat/omnitruck-unicorn-proxy && \
build habitat/omnitruck-poller && \
hab start $HAB_ORIGIN/omnitruck-unicorn-proxy && \
hab start $HAB_ORIGIN/omnitruck && \
hab start $HAB_ORIGIN/omnitruck-poller
