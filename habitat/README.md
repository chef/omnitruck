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

## Testing

Local testing:
- enter studio
- Execute `scripts/hab-it`
- `hab pkg exec core/curl curl "http://0.0.0.0/stable/automate/versions"`
- `hab pkg exec core/curl curl "http://0.0.0.0/_status"`
