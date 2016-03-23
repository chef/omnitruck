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

   './poller -e development'

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

## /metadata endpoint

The typical format of the metadata URL is:

   <http://localhost:9393/metadata?v=CHEF_VERSION&p=PLATFORM&pv=PLATFORM_VERSION&m=MACHINE_ARCHITECTURE>

Optional parameters:

   * `&nightlies=true`
   * `&prereleases=true`

As mentioned above, the CHEF_VERSION parameter is optional, if not supplied it will
provide the latest version, and if an iteration number is not specified, it will grab
the latest available iteration.  Partial version numbers are also acceptable (using v=11
will grab the latest 11.x client which matches the other flags).

If `&nightlies=true` or `&prereleases=true` then the endpoint will serve nightlies and/or prereleases and
only nightlies or prereleases (will not serve releases).  If both are specified then only packages
which are nightlies of prerelease versions will be served.  Prereleases are packages which have a
prerelease version identifier (e.g. 11.12.2.rc0).  Nightlies have a timestamp and gitsha
(11.12.2+20130101164140.git.2.deadbee).

The order of the parameters does not matter. This route needs to have access to the
build_list_v2.json in order to run, so make sure that you have one in the same directory as the app.
If you don't, see to the "Running the App" section and follow the instructions to
run the `poller`.

This endpoint returns a JSON or plain text document containing a URL to the desired
package along with a MD5 and SHA2-256 checksum of the package.  Clients should make a request
to download the package from the URL and then validate the MD5 or SHA2-256.

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

## /metadata-angrychef endpoint

<http://localhost:9393/metadata-angrychef>

This endpoint functions similarly to the /metadata endpoint but serves
data about angrychef packages.  It takes all the same options.

This endpoint generates its data from build_angrychef_list_v2.json.

## /full_angrychef_list endpoint

<http://localhost:9393/full_angrychef_list>

This endpoint provides the list of available angrychef builds for the install page.
Will return 404 with a file not found message if
./build_angrychef_list_v1.json does not exist, which is usually because the
s3 poller has not run or is misconfigured.

## /angrychef_platform_names endpoint

<http://localhost:9393/angrychef_platform_names>

This endpoint returns a mapping of short platform names, such as "el" to
long names, such as "Enterprise Linux". This is used by the install page
on the corpsite to populate the drop down boxes for the install list.

The document returned by this endpoint is essentially a verbatim copy of
./angrychef-platform-names.json; a 404 is returned if this file does
not exist on the server.

## /metadata-server endpoint

<http://localhost:9393/metadata-server>

This endpoint functions similarly to the /metadata endpoint but serves
data about chef-server packages.  It takes all the same options.

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

## /metadata-chefdk endpoint

<http://localhost:9393/metadata-chefdk>

This endpoint functions similarly to the /metadata endpoint but serves
data about chefdk packages.  It takes all the same options.

This endpoint generates its data from build_chefdk_list_v2.json.

## /full_chefdk_list endpoint

<http://localhost:9393/full_chefdk_list>

This endpoint provides the list of available chefdk builds for the install page.
Will return 404 with a file not found message if
./build_chefdk_list_v1.json does not exist, which is usually because the
s3 poller has not run or is misconfigured.

## /chef_chefdk_platform_names endpoint

<http://localhost:9393/chefdk_platform_names>

This endpoint returns a mapping of short platform names, such as "el" to
long names, such as "Enterprise Linux". This is used by the install page
on the corpsite to populate the drop down boxes for the install list.

The document returned by this endpoint is essentially a verbatim copy of
./chefdk-platform-names.json; a 404 is returned if this file does
not exist on the server.

## /metadata-container endpoint

<http://localhost:9393/metadata-container>

This endpoint functions similarly to the /metadata endpoint but serves
data about chef-container packages.  It takes all the same options.

This endpoint generates its data from build_container_list_v2.json.

## /full_container_list endpoint

<http://localhost:9393/full_container_list>

This endpoint provides the list of available chef-container builds for the install page.
Will return 404 with a file not found message if
./build_container_list_v1.json does not exist, which is usually because the
s3 poller has not run or is misconfigured.

## /chef_container_platform_names endpoint

<http://localhost:9393/chef_container_platform_names>

This endpoint returns a mapping of short platform names, such as "el" to
long names, such as "Enterprise Linux". This is used by the install page
on the corpsite to populate the drop down boxes for the install list.

The document returned by this endpoint is essentially a verbatim copy of
./chef-container-platform-names.json; a 404 is returned if this file does
not exist on the server.

## /_status endpoint

<http://localhost:9393/_status>

This endpoint provides information about the status of the app.

# Deprecated URLs

These download urls should not be used.  The corresponding /metadata endpoints should be
hit instead, and then clients should pull the url to download out of the returned json.

These endpoints are not feature compatible and there is no "yolo mode" for the download
endpoints (new versions of operating systems do not automatically get old package versions
promoted to them).  It will appear that many downloads are "broken" if clients hit the
download endpoint directly.

## /download

To test the download route, the url is:

   <http://localhost:9393/download?v=CHEF_VERSION&p=PLATFORM&pv=PLATFORM_VERSION&m=MACHINE_ARCHITECTURE>

As mentioned above, the CHEF_VERSION parameter is optional, if not supplied it will
provide the latest version, and if an iteration number is not specified, it will grab
the latest available iteration. The order of the parameters does not matter. This
route needs to have access to the build_list_v1.json in order to run, so make sure that
you have one in the same directory as the app. If you don't, go back to the "Running
the App" section and follow the instructions to run the poller.

## /download-server

To test the download-server route, the url is:

   <http://localhost:9393/download-server?v=CHEF_SERVER_VERSION&p=PLATFORM&pv=PLATFORM_VERSION&m=MACHINE_ARCHITECTURE>

Similar to the /download endpoint only it pulls data from build_server_list_v1.json.

## /download-chefdk

To test the download route, the url is:

   <http://localhost:9393/download?v=CHEF_VERSION&p=PLATFORM&pv=PLATFORM_VERSION&m=MACHINE_ARCHITECTURE>

Similar to the /download endpoint only it pulls data from build_chefdk_list_v1.json.

## /download-container

To test the download route, the url is:

   <http://localhost:9393/download?v=CHEF_CONTAINER_VERSION&p=PLATFORM&pv=PLATFORM_VERSION&m=MACHINE_ARCHITECTURE>

Similar to the /download endpoint only it pulls data from build_container_list_v1.json.

# Poller

The Poller lists release manifests (generated by `jenkins/release.rb`
in the omnibus-chef project) and merges them into a combined list of
available packages. The names of the combined package lists are
configurable, but we generally use:

* chef-manifest.json
* chefdk-manifest.json
* chef-server-manifest.json
* angrychef-manifest.json

# Platform mapping

The PlatformDSL class implements a DSL for describing mapping between different
platforms.  The configuration is in the root of the project in the `platforms.rb`
configuration file.  All platforms must be defined in this file even if no
manipulation is done to remap the platform name or platform version.

The platform DSL allow for remapping platform_version strings to strip out the
minor versions (making RHEL 6.4 and RHEL 6.5 be considered the same version --
something that is not true for Ubuntu 12.04 and Ubuntu 12.10).  It also allows
for remapping the platform name (making centos, oracle, scientific, etc all
map onto the "el" platform).  It can also do arbitrary remapping of the platform
version either onto a fixed number (serving RHEL6 binaries to all Amazon platforms
currently), or via a function that can take the source platform version number
and process it to produce a version to use internally (this is used to map
Linux Mint versions onto their corresponding Ubuntu versions).

The convention is to keep the platform names that install.sh supplies consistent
with ohai platform names.

This convention was not always applied consistently in the past, so that "el" is the
internal name for RHEL artifacts.  The install.sh code has been changed so that "el" is
no longer a distro name which install.sh detects (but omnitruck will still respond to
"el" like it is a platform of "redhat").

All of the platform name and platform_version mangling should be moved from install.sh
into this configuration file.

# "Yolo" mode

We only test certain artifacts running on certain distros and do not have complete coverage
across all distros that can run omnibus artifacts.  For example, we do no testing of Linux
Mint at all.  We also lag the distribution release, since getting a new tester into our
CI testing is not as easy as it should be (particularly for distros like Mac OSX where we
have laptops running jenkins as testers -- although this is getting better virtualized
now).  What "yolo" mode does is offer an artifact that we believe will work fine on the
distribution, and will warn that user that we have not tested on that platform.

This will also let users deploy old versions of Chef on new distros where we never tested
those old versions on that distro.  The previous distro version will get promoted by
yolo.

Packages which have been yolo-promoted have "yolo: true" in their JSON output from the
metadata endpoint.  The install.sh script will also print a banner warning if it encounters
a yolo mode package.  It is up to the end user as to if they're willing to accept the
risk of installing yolo-promoted packages (generally desktops and testing infrastruture
is fine, but production infastructure use is discouraged).

Yolo mode does occasionally cause issues, and the compiler toolchain and native gem
installation is one possible cause of trouble, e.g.:

http://www.getchef.com/blog/2014/03/26/breaking-changes-xcode-5-1-osx/

# Unit tests

There are unit tests in the spec/ directory which can be run by running 'rspec'
in the top directory of the project. Default values are stored in the .rspec
file.

## License
Apache 2 Licensed. See LICENSE for full details.
