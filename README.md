# Omnitruck

Omnitruck makes it easy to download and install omnibus artifacts. It provides an API to query the available versions of artifacts, get detailed information about the available versions and download them.

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

`m` => "x86_64", "i386", "powerpc", "sparc", "ppc64le", "ppc64", "s390x"

### `/$channel/$project/download`

Supports the same options with the `/$channel/$project/metadata` endpoint and instead of returning package information, it returns a redirect to the `"url"` set in the package information.

### `/$channel/$project/packages`

This api is similar to `/$channel/$project/metadata` but instead of returning information about a single package, it returns information about all packages that have the same version number.

Response is an array of objects returned by `/$channel/$project/metadata` endpoint. Supports `v` but does not support `p`, `pv` or `m`.

### `/$channel/$project/versions/all`

Returns a list of available version numbers for a particular channel and project combination

### `/$channel/$project/versions/latest`

Returns the latest version number for a particular channel and project combination

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
* /$channel/$project/versions

## Poller

`./poller` is a tool that populates a Redis cache with information about the available versions of Chef Software, Inc. packages. In production is runs every 5 minutes with a cron job.

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

Packages which have been yolo-promoted have "yolo: true" in their JSON output from the metadata endpoint.  The install.sh script prints a banner warning if it encounters a yolo mode package.  It is up to the end user as to if they're willing to accept the risk of installing yolo-promoted packages (generally desktops and testing infrastructure is fine, but production infrastructure use is discouraged).

### Version Fallback Comparison

The shift in `mac_os_x` from a MAJOR.MINOR versioning scheme (e.g., macOS 10.15) to a MAJOR-only versioning scheme (e.g., macOS 11) necessitated a modification in our version sorting logic. This is due to [omnibus-related behavior](https://github.com/chef/omnibus/pull/1002) that would identify, upload, and tag macOS 11 builds using MAJOR.MINOR versions (e.g., 11.0, 11.1, 11.2, etc) when the relevant platform version was only the MAJOR version (e.g., 11).

To handle environments that have a mix of equivalent MAJOR.MINOR and MAJOR builds in their artifact stores, we now compare versions using only shared version elements. This ensures that versions are sorted correctly, while still respecting Yolo mode behavior.

Example Comparison | Fallback Comparison | Result
--- | ---
`"11" <=> "11.0"` | `"11" <=> "11"` | Equivalent
`"11.2" <=> "11"` | `"11" <=> "11"` | Equivalent
`"10.15" <=> "11"` | `"10" <=> "11"` | Less Than

## Development

### Running the app

There are two parts to running omnitruck.

First, you need to populate its cache. Redis is used for the cache, and you will want to have a redis server running beforehand:

```bash
# Choose the following to install redis based on your OS
brew install redis
apt-get install redis
# Then just start it manually
redis-server
```

In production the cache populating is handled by a cron job. For development, you need to do this manually:

```bash
bundle install
bundle exec ./poller -e development
```

Omnitruck and the poller default to localhost when it looks for a redis
server, so you don't need to do anything special to get it to use the server
you started earlier.  If you have redis running elsewhere, then you will want
to set the `REDIS_URL` environment variable to point it at the correct server.

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

### Updating Mock Data

1. Execute a special implementation of the poller
    ```
    bundle install
    bundle exec rake refresh_data
    ```
2. Update the latest version methods in `spec/spec_helper.rb`
3. Update any tests that may no longer be accurate. This is especially true for tests that expect a specific package or package version to exist in the current channel. Artifacts in the current channel expire after a certain time, so tests may become invalid.

## License

- Copyright:: Copyright (c) 2010-2019 Chef Software, Inc.
- License:: Apache License, Version 2.0

```text
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
