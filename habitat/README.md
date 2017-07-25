omnitruck
- ruby scaffolding
- shared config
- shared env vars

omnitruck-poller
- depends on omnitruck
- runs poller service

omnitruck-web
- depends on omnitruck
- runs unicorn service

omnitruck-web-proxy
- unicorn nginx config
- used by omnitruck-web service

build 'em all; start 'em all

They'll work it out

Local testing:
- enter studio
- run `/habitat/go.sh`
- `hab pkg exec core/curl curl 0.0.0.0:80/stable/automate/versions` (and the like)
