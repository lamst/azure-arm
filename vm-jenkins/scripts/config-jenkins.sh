#!/bin/bash

# Perform upgrades
sudo apt-get update
sudo apt-get upgrade -y

# Install Java 8
sudo apt-get install openjdk-8-jdk -y

# Install Maven
sudo apt-get install maven -y

# Jenkins
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update
sudo apt-get install jenkins -y

# Docker
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install docker-ce -y

# Docker Compose
sudo curl -L https://github.com/docker/compose/releases/download/1.20.0-rc1/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Azure CLI
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
curl -L https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo apt-get install apt-transport-https -y
sudo apt-get update && sudo apt-get install azure-cli -y

# Kubectl
# cd /tmp/
sudo curl -kLO https://storage.googleapis.com/kubernetes-release/release/v1.8.0/bin/linux/amd64/kubectl
sudo chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

# .NET Core 1.0.4, 1.1.7, and 2.1.4
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
sudo mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod xenial main" > /etc/apt/sources.list.d/dotnetdev.list'
sudo apt-get update
sudo apt-get install dotnet-dev-1.0.4 -y
sudo apt-get install dotnet-dev-1.1.7 -y
sudo apt-get install dotnet-sdk-2.1.4 -y

# Configure access
sudo usermod -aG docker jenkins
sudo usermod -aG docker azureuser
sudo touch /var/lib/jenkins/jenkins.install.InstallUtil.lastExecVersion
sudo service jenkins restart
