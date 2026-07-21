# Docker usage

## Build Docker Image

The dockerfile used to build the docker image is located in docker/downloader/Dockerfile. It is important to note that 
the `docker build` command must be run from the root of the repository to build correctly. 

Example:

```shell
docker build -f docker/downloader/Dockerfile -t medusa-downloader .
```

To create a Docker container from this image, the following things need to happen.
* The container is started with application configuration files mounted in the right places
* The container port 3000 is forwarded to a port accessible on the host
* The run command args for starting the application. 

Example:

```shell
docker run -v ./tempfiles/database.yml:/app/config/database.yml:ro -v ./tempfiles/production.yml:/app/config/production.yml:ro -p 3000:3000 medusa-downloader
```

## Docker Compose

To use Docker Compose to run medusa-downloader and the services it depends on, a Docker
Compose Override yaml file will need to be created and configured to mount the 
configuration files needed by Rails application to run.

This file will need to be named "docker-compose.override.yml"

Example content of docker-compose.override.yml: 

```yaml
services:
  downloader:
    volumes:
      - ./tempfiles/database.yml:/app/config/database.yml:ro
      - ./tempfiles/development.local.yml:/app/config/settings/development.local.yml:ro

```