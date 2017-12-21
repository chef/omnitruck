## Packages

# omnitruck-app
- shared config
- shared env vars

Install core Omnitruck Sinatra application and shared files

# omnitruck-poller
- runs poller service

Polls packages.chef.io periodically to scrape package properties to generate
package metadata json files used to respond to queries.

# omnitruck-web
- runs unicorn service

Provides Unicorn HTTP server and exposes a Unix and TCP socket.

# omnitruck-web-proxy
- unicorn nginx config

Provides Nginx proxy for connection routing and caching, and connects to the
omntruck-web unix socket.

## Scaffolding (Gemfile and Gemfile.lock)

`omnitruck-app`,  `omnitruck-web`, `omnitruck-poller` setup `scaffolding-ruby`.
This is so each package can find `bundler` in the `run` hooks. Since `scaffolding-ruby`
search for Gemfile and Gemfile.lock files in specific locations the initial approach
is to simply copy the project Gemfile and Gemfile.lock files to the `omnitruck-web`
and `omnitruck-poller` package directories.

## Testing

Local testing:
- enter studio
- Execute `scripts/hab-it`
- `hab pkg exec core/curl curl "http://0.0.0.0/stable/automate/versions"`
- `hab pkg exec core/curl curl "http://0.0.0.0/_status"`
