# Introduction

The purpose of this project is to automate the release process of Omnibus artifacts.
This web service handles the mapping from platform, platform version, chef version,
and architecture to the appropriate artifact. This mapping relies on the new
standardized naming scheme for Omnibus artifacts. Instead of needing to modify
the install.sh script, the process gets simplified to one click. Chef version is
an optional parameter, if it isn't provided, the app will serve up the latest
iteration of the latest version of chef client. If no iteration number is specified,
it will serve the latest iteration of the specified version.

This web app runs on Sinatra, a very light Ruby web app framework that runs on Rack,
and uses Unicorn.

# Running the app

To run the app for development, shotgun is a very useful tool. It handles each request
in a new process to reload the application each time a new request is made, that way you
don't have to start and stop the server every time you want to test a change youve made.
To get shotgun:

   'gem install shotgun'

In order to run the app, we must first build the various build_*list*.json files so that the app
knows what versions are available, so run:

   './s3_poller -e development'

See the S3 Poller section later in this document for more information.

To run the app locally, run this in the application directory:

   'shotgun config.ru'

This will launch a Rack server that will run the Omnitruck app at http://localhost:9393/
(the port number will only be 9393 if using shotgun, it will vary with other methods). 

<b>NOTE: The unfortunate thing about shotgun is that it does not output any default logging.
To see the default logging, you will need to just run unicorn without shotgun:</b>

   'unicorn'

# Working with the app

## Sinatra

This is the first project that we have done using Sinatra. For documentation, look here,
starting with the README: <http://www.sinatrarb.com/>

There are only two routes that this app provides - one to serve up the install.sh script,
and one to download the chef client that will be specified by the install script. For
dev and testing purposes, open a browser and use the base url <http://localhost:9393/>
to access the routes. Again, port will vary depending on how you run the app, though I
highly recommend shotgun. Shotgun will allow you to make a change to the code without
needing to restart the server to make another request.

## /install.sh

To test the install.sh route, simply navigate to:

<http://localhost:9393/install.sh>

This will render the install.sh.erb temlate with the appropriate base url for chef
client downloads. This base url is contained in a config.yml and depends on your
environment (development, test, or production).

## /download

To test the download route, the url is:

   <http://localhost:9393/download?v=CHEF_VERSION&p=PLATFORM&pv=PLATFORM_VERSION&m=MACHINE_ARCHITECTURE>

As mentioned above, the CHEF_VERSION parameter is optional, if not supplied it will
provide the latest version, and if an iteration number is not specified, it will grab
the latest available iteration. The order of the parameters does not matter. This
route needs to have access to the build_list_v1.json in order to run, so make sure that
you have one in the same directory as the app. If you don't, go back to the "Running
the App" section and follow the instructions to run the s3_poller.

## /metadata endpoint

<http://localhost:9393/metadata>

This endpoint accepts the same query parameters as /download to select a
desired package version and iteration. Instead of returning a redirect
to the desired package, it returns a JSON or plain text document
containing a URL to the desired package along with a MD5 and SHA2-256
checksum of the package.

This endpoint generates its data from build_list_v2.json.

## /full_client_list endpoint

<http://localhost:9393/full_client_list>

This endpoint provides the list of available client builds for the install page. 
Will return 404 with a file not found message if ./build_list_v1.json
does not exist, which is usually because the s3 poller has not run or is
misconfigured.

## /chef_platform_names endpoint

<http://localhost:9393/chef_platform_names>

This endpoint returns a mapping of short platform names, such as "el" to
long names, such as "Enterprise Linux". This is used by the install page
on the corpsite to populate the drop down boxes for the install list.

The document returned by this endpoint is essentially a verbatim copy of
./chef-platform-names.json; a 404 is returned if this file does not
exist on the server.

## /metadata-server endpoint

<http://localhost:9393/metadata-server>

This endpoint functions similarly to the /metadata endpoint but serves
data about chef-server packages.

This endpoint generates its data from build_server_list_v2.json.

## /full_server_list endpoint

<http://localhost:9393/full_server_list>

This endpoint provides the list of available server builds for the install page.
Will return 404 with a file not found message if
./build_server_list_v1.json does not exist, which is usually because the
s3 poller has not run or is misconfigured.

## /chef_server_platform_names endpoint

<http://localhost:9393/chef_server_platform_names>

This endpoint returns a mapping of short platform names, such as "el" to
long names, such as "Enterprise Linux". This is used by the install page
on the corpsite to populate the drop down boxes for the install list.

The document returned by this endpoint is essentially a verbatim copy of
./chef-server-platform-names.json; a 404 is returned if this file does
not exist on the server.

## /_status endpoint

<http://localhost:9393/_status>

This endpoint provides information about the status of the app.

# S3 Poller

The S3 Poller lists release manifests (generated by `jenkins/release.rb`
in the omnibus-chef project) and merges them into a combined list of
available packages. The names of the combined package lists are
configurable, but we generally use:
* build_list_v1.json
* build_list_v2.json
* build_server_list_v1.json
* build_server_list_v2.json

The v1 versions of the package lists have checksum information stripped
so that the omnitruck app does not need to do any processing when
serving the full_client_list or full_server_list endpoints (the
documents served by these endpoints omit checksums for compatiblity
reasons).

Release manifests have keys like
"{chef,chef-server}-release-manifest/$VERSION.json". We currently use
the 'opscode-omnibus-package-metadata-test' bucket for dev/preprod and
"opscode-omnibus-package-metadata' for prod. The S3 poller expects these
buckets to be publicly listable and the release manifests to be publicly
readable.


# Unit tests

There are unit tests in the spec/ directory which can be run by running 'rspec'
in the top directory of the project. Default values are stored in the .rspec 
file.

Backup
------

A tool for pulling all the builds from s3 and putting them into a file and directory
format that omnibus-chef/jenkins/release.rb can parse. This is useful for, say, 
re-initializing the metadata or moving between s3 buckets / accounts (was originally
written to add checksums to the package metadata).

See backup/readme.md for more info.

# Package Verification

The omnitruck-verifier directory contains a tool for verifying that
packages on S3 have not been tampered with by comparing their checksums
to the checksums specified by a cached copy of the metadata files. See
the README in that directory for more info.

## License
Apache 2 Licensed. See LICENSE for full details.

