# Update the apt package list and install dependencies
apt-get update
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common

# Add the Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

# Add the Docker stable repository
add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) \
  stable"

# Update the apt package list and install Docker
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Add the current user to the docker group so you don't have to use `sudo` to run Docker commands
usermod -aG docker $USER
