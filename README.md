**omnitruck** makes it easy to download and install omnibus artifacts. It provides an API to query the available versions of artifacts, get detailed information about the available versions and download them.

Powered by [Sinatra](https://www.sinatrarb.com/).

## Endpoints

### `/install.sh` & `/install.ps1`

Renders the install script for Chef packages.

`mixlib-install` is used under to covers to generate the scripts. The base url for the scripts will be equivalent to the base url of the running omnitruck instance.

### `/$channel/$project/metadata`

Returns package information based on the provided parameters. Returned information can be `json` or `txt` and it looks like:

```
json:
{
  "url": "...",
  "sha1":	"...",
  "sha256": "...",
  "version": "..."
}

text:
url\t...\nsha1\t...\nsha256\t...\nversion\t...\n
```

Supported parameters are:

|      | Description |
|------|-------------|
| `v`  |  Version string. It can be full (12.9.2) or partial (12). If omitted, the latest version will be used. |
| `p`  |  Platform string. |
| `pv` | Platform version string.  |
| `m`  | Architecture string.  |

`v` is the most tricky one:

* If omitted omnitruck will return information for the latest available version.
* When set to a full version string, omnitruck will return information for that specific version.
* When set to a partial string, omnitruck will return information for the latest version available that is matching the given string. E.g. if `"12"` is given, omnitruck will return the latest `"12.X.Y"` and if `"12.6"` is given, omnitruck will return the latest `"12.6.Y"`.

The values that `p`, `pv` & `m` can take include but are not limited to:

`p` => "aix", "debian", "el", "freebsd", "ios_xr", "mac_os_x", "nexus", "solaris2", "ubuntu", "windows", "solaris", "sles", "suse", "arista_eos"

`pv` => `MAJOR.MINOR` version of the platform. E.g. "6.1", "7.1" for "aix", "6", "7", "8" for debian. For windows "2008r2"

`m` => "x86_64", "i386", "powerpc", "sparc", "ppc64le", "ppc64"

### `/$channel/$project/download`

Supports the same options with the `/$channel/$project/metadata` endpoint and instead of returning package information, it returns a redirect to the `"url"` set in the package information.

### `/$channel/$project/versions`

This api is similar to `/$channel/$project/metadata` but instead of returning information about a single package, it returns information about all packages that have the same version number.

Response is an array of objects returned by `/$channel/$project/metadata` endpoint. Supports `v` but does not support `p`, `pv` or `m`.

### `/_status`

Return the status of the application in `json` format.

## Deprecated Endpoints

Historically omnitruck supported different naming conventions in its endpoints. So we have a big set deprecated endpoints. These endpoints are currently working and they are redirected to one of the supported endpoints.

* /download
* /metadata
* /download-server
* /metadata-server
* /full_client_list
* /full_list
* /full_server_list
* /chef/full_client_list
* /chef/full_list
* /chef/full_server_list
* /metadata-chefdk
* /download-chefdk
* /chef_platform_names
* /chef_server_platform_names
* /chef/chef_platform_names
* /chef/chef_server_platform_names
* /chef/metadata-chefdk
* /chef/download-chefdk
* /chef/metadata-container
* /chef/download-container
* /chef/metadata-angrychef
* /chef/download-angrychef
* /chef/download-server
* /chef/metadata-server
* /chef/install.msi
* /install.msi
* /full_$project_list
* /$project_platform_names
* /$channel/$project/platforms

## Poller

`./poller` is a tool that populates a cache with information about the available versions of Chef packages. In production is runs every 5 minutes with a cron job.

It polls <https://bintray.com/chef> and creates files named `$channel\$project-manifest.json` under the configured metadata directory.

## Version Resolution

Version resolution is the most complex and fragile section of omnitruck. In addition to handling historical differences between the packages published by Chef (different package naming conventions, different metadata, different architecture naming) it supports some interesting logic to find the right package for a given platform.

### Platform Mapping

`PlatformDSL` and the main configuration file `platforms.rb` gives omnitruck the ability to map builds released for a platform to be available for another platform. Some of the use cases enabled in `platforms.rb` are:

* Making RHEL 6.4 and RHEL 6.5 be considered the same version but not considering Ubuntu 12.04 and Ubuntu 12.10 as same.
* Making centos, oracle, scientific, etc all map to the "el" platform.

The convention is to keep the platform names that install.sh supplies consistent with ohai platform names.

This convention was not always applied consistently in the past, so that "el" is the internal name for RHEL artifacts.  The install.sh code has been changed so that "el" is no longer a distro name which install.sh detects (but omnitruck will still respond to
"el" like it is a platform of "redhat").

All of the platform name and platform_version mangling should be moved from install.sh into this configuration file.

### "Yolo" mode

We only test certain artifacts running on certain distros and do not have complete coverage across all distros that can run omnibus artifacts.  For example, we do no testing of Linux Mint at all.  We also lag the distribution release, since getting a new tester into our CI testing is not as easy as it should be (particularly for distros like Mac OSX where we have laptops running jenkins as testers -- although this is getting better virtualized now).  What "yolo" mode does is offer an artifact that we believe will work fine on the distribution, and will warn that user that we have not tested on that platform.

This will also let users deploy old versions of Chef on new distros where we never tested those old versions on that distro.  The previous distro version will get promoted by yolo.

Packages which have been yolo-promoted have "yolo: true" in their JSON output from the metadata endpoint.  The install.sh script prints a banner warning if it encounters a yolo mode package.  It is up to the end user as to if they're willing to accept the risk of installing yolo-promoted packages (generally desktops and testing infrastruture is fine, but production infastructure use is discouraged).

## Development

### Running the app

There are two parts to running omnitruck.

First, you need to populate its cache. In production this is handled by a cron job. For development, you need to do this manually:

```bash
bundle install
bundle exec ./poller -e development
```

Second part is to run omnitruck web server. In production it runs in unicorn. For development, you have two options:

1. `shotgun` does not output any of the logs, but reloads the application for each request so that you do not need to reload the application when you change a file.
2. `unicorn` gives you all the logs but requires you to restart when you change a file.

#### Using `shotgun`

```bash
gem install shotgun
shotgun config.ru
```

#### Using `unicorn`

```bash
bundle install
bundle exec unicorn
```

## License
Apache 2 Licensed. See LICENSE for full details.
