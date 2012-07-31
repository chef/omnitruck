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

In order to run the app, first there must exist a build_list.json file so that the app
knows what versions are available, so run:

   './s3_poller'

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
route needs to have access to the build_list.json in order to run, so make sure that
you have one in the same directory as the app. If you don't, go back to the "Running
the App" section and follow the instructions to run the s3_poller.

## /full_list endpoint

<http://localhost:9393/full_list>

This endpoint provides the list of available builds for the install page.

## /_status endpoint

<http://localhost:9393/_status>

This endpoint provides information about the status of the app.

# S3 Poller

The S3 Poller uses UberS3 to access S3. The credentials to connect to S3 will be
pulled from config/config.yml. For development and testing purposes, you can edit
the config.yml.example to use the correct credentials and target the right bucket.

The S3 Poller will merge the platform support files located in the "/platform_support"
directory of the S3 bucket to create one large list that is organized by target
platform. It is this list that gets passed on to the Sinatra app.