# Omnitruck Verifier #

Omnitruck Verifier fetches metadata about Omnibus packages from S3 and
verifies the integrity of those packages. It's primary purpose is to
provide monitoring of Omnibus package integrity.

## Design Basics

As part of the Omnibus release process, metadata files describing the
packages and their checksums (MD5 and SHA2-256) are uploaded to an S3
bucket (currently 'opscode-omnibus-package-metadata').
`omnitruck-verifier` fetches these metadata files and caches them locally.
It then verifies package integrity by checking that the packages'
checksums match those specified in the metadata files. Additionally,
once a metadata file is locally cached, `omnitruck-verifier` will verify
that it has not been tampered with by comparing the checksum of the
cached file against the remote version.

### Quick Check Mode

The "quick" verify mode is the only one currently implemented. In this
mode, `omnitruck-verifier` never downloads anything except for new
metadata files (corresponding to new omnibus releases). To verify
package integrity, it relies on S3 to provide MD5 sums of files in
bucket listings. This is good, because many Omnibus packages are very
large and take quite a while to download. On the other hand, MD5 is
pretty broken nowadays, so it might be possible for a sufficiently
clever attacker to defeat this check.

To remedy the shortcomings of the MD5 based check, a slower but stronger
mode of operation (involving downloading packages and computing SHA2-256
sums) is planned.

## Running It

This is a ruby project using bundler, so `bundle install` to acquire
deps. Run `bin/quick-verify` to run the verifier.

### In Production

By default, `verify-quick` produces verbose output with statistics about
the number of releases and packages available, and detailed information
about checksum mismatches. This output is suitable for testing the
verifier or manually verifying packages, but not for nagios. To enable
nagios formatted output add the `--nagios` command line flag.

`verify-quick` caches checksums in `~/.omnibus-verify` by default. In
production we will want to configure it to store data elsewhere. This
can be configured using the `-c CACHE_DIR` command line option.

## Impending Multipart Upload Doom

If files are uploaded using multipart uploads, AWS uses a different
system to compute the etag of the file, so it is no longer the MD5 of
the file. This sucks for us, because we want to compare the MD5 of the
file on S3 with the one we computed when uploading the file. Our current
release process involves using `s3cmd` to upload the file. Newer
versions of `s3cmd` will start automatically using multipart uploads for
all files larger than 15 MB. Luckily, we can configure the old behavior,
but `s3cmd` doesn't accept unknown command line options, so we can't
prepare in advance without upgrading `s3cmd`.

References:
* http://s3tools.org/s3cmd-110b2-released
* https://forums.aws.amazon.com/thread.jspa?messageID=293789

