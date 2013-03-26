# Omnibus Package Checksums

## Goals

We want to create checksums of the omnibus packages we distribute. These
checksums will be displayed on the Chef install page alongside links to
the packages. The `install.sh` script will fetch the checksums and use
them to verify package downloads. To ensure the integrity of the
checksums is not affected by a compromise of the preprod S3 key, the
checksums need to be stored elsewhere.

**Non Goals:** Some package systems support package signing with public
key crypto (RPM and apt use GPG, Windows uses X.509 certificates, etc.)
We would like to implement "native" package repos and signing for these
platforms **in addition to** this proposal.

## Design Overview

1. Update to the release.rb script to compute the checksums. On older
   systems, only md5 may be available, but we should use SHA2-256 or
   even 512 for better security on newer systems.
2. Update Omnitruck to fetch the checksum data. Omnitruck will also
   provide a new metadata endpoint that serves checksum data.
3. Update install.sh to use the new endpoint to fetch checksum
   information and verify downloads.
4. Update Chef install page to fetch and display checksum information.
5. Automatically monitor package integrity from (probably) Nagios.


## Design Detail

### client_full_list Document Format Change

The format of the JSON document given by the full list endpoint
( https://www.opscode.com/chef/full_client_list ) will be updated. The
current version is structured as so:

```json
{
  "debian": {
    "6": {
      "x86_64": {
        "10.12.0-1": "/debian/6/x86_64/chef_10.12.0-1.debian.6.0.5_amd64.deb",
```

The new version will add another layer including checksum data for each
package:

```json
{
  "debian": {
    "6": {
      "x86_64": {
        "10.12.0-1": {
          "rel_path": "/debian/6/x86_64/chef_10.12.0-1.debian.6.0.5_amd64.deb",
          "md5": "123def...",
          "sha256": "456abc..."
        }
```

To avoid breaking users of this document, the old format document will
be available at the current URL. We may introduce API versioning to
accomodate the change. Though I consider it suboptimal philosophically,
I think URL-based api versioning may be the best pragmatic choice here,
i.e.,  https://www.opscode.com/chef/v2/full_client_list would be the URL
for the new format.

This will initially be added as an opt-in only feature. Release script
will use presence of a command line flag to enable publishing v2
metadata to the metadata S3 account.

### S3 Storage of Checksum Documents

A new S3 account will be created for the purpose of storing the checksum
documents. I had considered using the prod S3 account but using a custom
account allows us to constrain the number of places where the
credentials for uploading/modifying checksums are exposed and also to
avoid increasing the attack surface for the prod S3 credentials. The
downside of adding a new account is that it is yet another set of keys
we need to change when revoking access from a former employee.

### Release Script Changes

The release script will be updated to upload package metadata with
checksums to a separate S3 account. For some period of time, we will
continue to publish the old format metadata as before.

### Omnitruck Metadata Endpoint

To support install.sh, we'll add a metadata endpoint to omnitruck.
Requests will use the same GET API with query parameters as the current
download endpoint. The response will be in a to-be-determined format
that is easily parseable with cross-platform shell scripting tools (for
example, `awk` on Solaris 9 is ancient). If it's easy, we may add a JSON
format which could be selected by content negotiation.

### Monitoring

Monitoring will go through Nagios. Nagios will automatically check the
list of md5 sums from omnitruck metadata against Amazon via HEAD
requests for the artifacts. Monitoring will also cache the checksums
reported by omnitruck and alert if the reported checkums change.

### New S3 Account/Bucket for Omnibus Packages

Builds currently are uploaded to a S3 account we also use for other
purposes. We have created a new S3 account with the sole purpose of
storing Omnibus packages. To cut over from the old account/bucket to the
new ones, we'll do the following:

* Fetch the old data, and upload it along with new format metadata.
* Configure Jenkins servers with necessary credentials to publish to the
new locations.
* Deploy updated omnitruck with support for new package and metadata
locations.
* Merge release.rb changes to publish packages and metadata to the new
locations.

