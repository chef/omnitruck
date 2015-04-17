Omnitruck Backup Utility
==========================================================

As stated in the main readme, the original purpose of this was to
re-upload via omnibus so that it re-parsed all the packages into
a format omnibus understands, originally to back-populate checksums.

The end goal is to parse the packages into the omnibus dir structure of:
CHEF_PACKAGE_VERSION/JENKINS_FILTER/pkg/PACKAGE_FILENAME

Where an example of JENKINS_FILTER is a folder named:
build_os=centos-5,machine_architecture=x64,role=oss-builder

Usage
-----

**If you want to understand the utility, follow along, if not, just
follow steps in code blocks.**

Unfortunately, the naming conventions between omnibus and omnitruck
are wildly inconsistent ("intel" maps to "i386" for example). Therefore,
we must create a backwards mapping between the two.

So, in order to put the files in a format omnibus will understand
we must reverse the json in omnibus so that we can map the hash from
a build manifest i.e. OS => OS_VERSION => ARCH => CHEF_VERSION => FILENAME
to CHEF_PACKAGE_VERSION/JENKINS_FILTER/pkg/PACKAGE_FILENAME.

The script reverse-release-json.rb accomplishes this and outputs to reversed.json.

So, move the json from omnibus for client.

**Step 1**

    # if your omnibus-chef is out of date...should probably just do this anyway
    # cd omnibus-chef && git pull --rebase && cd opscode-omnitruck
  	cd backup
  	mv omnibus-chef/jenkins/chef.json
  	ruby reverse-release-json.rb chef.json
  	mv reversed.json chef-reversed.json

Now, we must set up s3cmd.

**Step 2**

    mv ../config/s3cfg.example ../config/s3cfg
    emacs ../config/s3cfg
    # replace BUCKET-ACCOUNT-KEY-HERE and BUCKET-SECRET-KEY-HERE with real values

Now we have s3cmd configured. Next we will run a script that will pull down _every_
manifest for client, parse it, and download every package into
backup/s3-client-backup into a format that works for omnibus.

**Step 3**

    # change permissions if necessary with
    # chmod +x backup-s3-bucket.sh
    ./backup-s3-bucket.sh

And now wait until you are an old man or woman! It will grab every client
build from:

s3://opscode-omnitruck-release/chef-platform-support/*.json excluding chef-platform json files and

and put them in the omnibus format of :

CHEF_PACKAGE_VERSION/JENKINS_FILTER/pkg/PACKAGE_FILENAME

with the help of s3-parse-manifest-json.rb.

