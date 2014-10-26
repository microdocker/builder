## Microdocker builder
This repository contains some tools for generating Dockerfiles that can
be used to build very lightweight docker images.

With this script, you can create a MongoDB image that takes only 23M
disk space.

## How it works
This script create Dockerfiles based on busybox. When you run this script,
it'll analyse the binary file that you specified and resolves all the 
libraries that it depends on. Then it'll create a temporary directory and
copy all the libraries to the temporary directory. After that it'll add 
all the depended files to the Dockerfile.

When the Dockerfile is successfully generated, you can either edit it to 
add you own stuffs or build it directly.

## Usage
Type ./dockerfile-generator.sh for help.

To create a micro image for MongoDB, just run the following commands:

Example:
Create mongodb image
Make sure the mongodb binary package has been installed.

```bash
cd examples
../dockerfile-generator.sh -b /usr/bin/mongod -p 27017 -d mongodb
```

Then edit the generated Dockerfile and change the CMD directive to 
```CMD ["/usr/bin/mongod", "--config", "/etc/mongodb.conf"]```, then run
```docker build -t micro_mongodb```.

The example mongodb image can be found here. 
https://registry.hub.docker.com/u/microdocker/mongodb/

## Copyright and License
Copyright (C) 2014 Shijiang Wei (mountkin) <mountkin@gmail.com>

License: [Apache 2.0](http://www.apache.org/licenses/LICENSE-2.0.txt)
