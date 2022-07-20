#!/bin/bash

# this script is designed to complete following tasks:
# - create a master kubernetes node
# - install and configure calico overlay

# set home directory
# set pod_network
# set Tokenfolder

HOME="/home/local_admin"
PODNET="192.168.0.0/16"
TOKENFOLDER="/opt/k8s"

# Update repository and install pre-requisites
echo 'Updating Repositories and isntalling pre-reqs..'
sudo apt-get update && sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# add repository GPG key and add repository as a source
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | \
    sudo tee /etc/apt/sources.list.d/kubernetes.list

# install k8s components and sets flag preventing automatic upgrade
echo 'Installing K8s components..'
sudo apt-get update && sudo apt-get install -y \
    kubelet \
    kubeadm \
    kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo 'Disabling Swap Settings..'
# Disable Swap, and disabling at startup
sudo swapoff -a
sudo sed -e '\/swap/ s/^#*/#/' -i /etc/fstab

# configuring overlay components
echo 'Configuring network overlay components..'
sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# installing and configuring containerd
echo 'Installing and configuring containerd..'
sudo apt-get update && install -y containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

# initializing container
echo 'Executing kubeadm cluster creation..'
sudo kubeadm init --pod-network-cidr $PODNET

# sleep allows for cluster conifguration to take effect
sleep 30 

# completes the k8s cluster configuration
echo 'Completing k8s cluster setup..'
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown "1000":"1000" $HOME/.kube/config

# install calico
kubectl create -f https://projectcalico.docs.tigera.io/manifests/tigera-operator.yaml
kubectl create -f https://projectcalico.docs.tigera.io/manifests/custom-resources.yaml

# creates a new join token and copies token to a folder.
K8STOKEN=$(sudo kubeadm token create --print-join-command)
sudo mkdir -p $TOKENFOLDER
echo "$K8STOKEN" | sudo tee "$TOKENFOLDER"/token

echo ' Installation has been completed. The new join token is located in the configured folder.'