# Project Title

This is a template for all of my .yaml files. It includes yamls for:
- Docker
- Kubernetes
- CircleCI
- Jenkins


## Docker

To install Docker on Ubuntu, follow these steps:

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

### Prerequisites

List any dependencies or requirements for the project.

### Installation

Step-by-step instructions on how to install and set up the project.

## Usage

Examples and explanations of how to use the project.

## Contributing

Instructions on how to contribute to the project, including guidelines for code style and any necessary prerequisites for submitting a pull request.

## License

Include information about the license of the project, such as which open source license you have chosen and how it affects the use of the code in your project.

## Acknowledgments

List any individuals or resources that have contributed to the project.
