listen "{{cfg.unicorn.listen}}:{{cfg.unicorn.listen_port}}", {{cfg.unicorn.listen_opts}}
timeout {{cfg.unicorn.timeout}}
preload_app {{cfg.unicorn.preload_app}}
worker_processes {{cfg.unicorn.worker_processes}}
