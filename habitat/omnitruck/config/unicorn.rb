listen "{{cfg.unicorn.listen}}", {:backlog=>{{cfg.unicorn.backlog}}, :tcp_nodelay=>{{cfg.unicorn.tcp_nodelay}}}
timeout {{cfg.unicorn.timeout}}
preload_app {{cfg.unicorn.preload_app}}
worker_processes {{cfg.unicorn.worker_processes}}