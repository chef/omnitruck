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
deps. Run `bin/quick_verify` to run the verifier. Options/arguments are
currently TBD.

### In Production

TBD.

