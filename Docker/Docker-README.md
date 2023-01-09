## Docker

1. You can install docker running this script:
```
bash install-docker.sh
```

2. To install Docker on Ubuntu, follow these steps:

```
sudo apt update

sudo apt install apt-transport-https ca-certificates curl software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

apt-cache policy docker-ce

sudo apt install docker-ce

sudo systemctl status docker

sudo usermod -aG docker ${USER}

su - ${USER}

docker

```

### Working with Docker
The following commands are useful for working with Docker:

## List all images
```
docker images
```

## List all containers
```
docker ps -a
```

## Remove all containers
```
docker rm $(docker ps -a -q)
```

# Remove Functions

## Remove all images
```
docker rmi $(docker images -q)
```

## Remove all images and containers
```
docker system prune -a
```

## Remove all dangling images
```
docker rmi $(docker images -f "dangling=true" -q)
```

## Remove all dangling volumes
```
docker volume rm $(docker volume ls -qf dangling=true)
```

## Remove all dangling networks
```
docker network rm $(docker network ls -qf dangling=true)
```

## Stop all containers
```
docker stop $(docker ps -a -q)
```

## Remove all stopped containers
```
docker rm $(docker ps -a -q)
```

## Enter a running container
```
docker exec -it <container_name> bash
```

## Stop and remove a container
```
docker stop CONTAINER_ID && docker rm CONTAINER_ID
```

## Check the status of a container
```
docker inspect -f '{{.State.Running}}' CONTAINER_ID
```

## Check the logs of a container
```
docker logs CONTAINER_ID
```

## Check the logs of a container in real time and follow
```
docker logs -f CONTAINER_ID
```

## Pull an image from Docker Hub
```
docker pull IMAGE_NAME
```

## Run a container from an image
```
docker run IMAGE_NAME
```

## Run a container from an image and map a port
```
docker run -p 8080:80 IMAGE_NAME
```

## Run a container from an image and map a volume
```
docker run -v /path/to/host:/path/to/container IMAGE_NAME
```

## Run a container from an image and map a volume and a port
```
docker run -p 8080:80 -v /path/to/host:/path/to/container IMAGE_NAME
```

## Push an image to Docker Hub
```
docker push IMAGE_NAME
```

## Build an image from a Dockerfile
```
docker build -t IMAGE_NAME .
```

## Build an image from a Dockerfile and map a volume
```
docker build -t IMAGE_NAME -v /path/to/host:/path/to/container .
```


# Docker Compose
The following commands are useful for working with Docker Compose:

## List all containers
```
docker-compose ps
```

## Build containers
```
docker-compose build
```

## Start containers
```
docker-compose up -d
```

## Stop containers
```
docker-compose stop
```

## Stop and remove containers
```
docker-compose down
```

## Enter a running container
```
docker-compose exec CONTAINER_NAME bash
```

## Check the logs of a container
```
docker-compose logs CONTAINER_NAME
```

## Check the logs of a container in real time and follow
```
docker-compose logs -f CONTAINER_NAME
```

## Check the status of a container
```
docker-compose inspect -f '{{.State.Running}}' CONTAINER_NAME
```

## Stop and remove a container
```
docker-compose stop CONTAINER_NAME && docker-compose rm CONTAINER_NAME
```

## Remove all containers
```
docker-compose rm -f
```

## Remove all images
```
docker-compose rmi -f
```


