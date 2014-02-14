# Installing Mac Packages From CLI

This document provides notes that should serve as a helpful starting
point for adding native Mac package support to install.sh.

Given an Apple disk image (.dmg), we can install chef like so:


## Mount the Disk Image

    $ hdiutil attach chef.dmg 
    /dev/disk1          	GUID_partition_scheme          	
    /dev/disk1s1        	Apple_HFS                      	/Volumes/Chef Client

## Run the Installer

    $ sudo installer -target / -pkg /Volumes/Chef\ Client/chef-mac.pkg 
    installer: Package name is Chef Client
    installer: Upgrading at base path /
    installer: The upgrade was successful.

## Unmount the Disk Image

    $ hdiutil detach /Volumes/Chef\ Client
    "disk1" unmounted.
    "disk1" ejected.
    
