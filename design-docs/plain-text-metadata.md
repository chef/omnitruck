# Omnitruck Plain Text Metadata

## Goal
The overall goal is for `install.sh` as served by omnitruck to verify omnibus
packages by comparing checksums of the downloaded packages against the correct
checksums. To accomplish this, omnitruck needs to serve package metadata in a
format easily consumed in the shell. We cannot rely on new or advanced features
of shell tools because we need to make this work on platforms such as Solaris
9.

## Format

The basic format is a set of key value pairs, separated by a tab, one pair per
line. Neither the key nor the value may contain a tab or space. At present, we
expect to have keys for URI, MD5, and SHA2-256, like so (tab characters shown
with `\t`):

    url\thttps://stuff.s3.amazonaws.com/debian/6/x86_64/chef-11.4.1-x86-64.deb
    md5\t6856a1b03fcb6d1efee50650b01e713c
    sha256\tf93823ad63e87c885b7077364e0aac0ce2ddddb7f05aa1761d225d46f8fbab8a

## Reading Values

Given the above format, we can extract the value for a key using `awk`:

    awk '$1 == "md5" { print $2 }' metadata.txt

