#!/bin/bash

# CentOS7.5 Minimal,docker-ce v18.06.0,registry v2.7.1
# Docker registry 私有仓库镜像查询、删除、上传、下载

# Author  Michael <user@example.com>

# Script run root
if [[ $UID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# 参数 variable
# image="image_name:image_version"


# 访问仓库地址：xx.xx.xx.xx:443
registry_addr="192.168.1.105:443"
registry_url="https://192.168.1.105:443"

# auth 认证用户名密码
auth_user="test"
auth_passwd="Test@123"


# login docker registry
docker login ${registry_addr} -u ${auth_user}  -p "${auth_passwd}"

# 检测仓库的可用性
function check_registry() {
  curl -s -u ${auth_user}:${auth_passwd} ${registry_url}/v2/_catalog > /dev/null 2>&1 
  if [ $? -ne 0 ]; then
    echo -e "Connect to registry server ${registry_url} failed!"
  else
    echo -e "Connect to registry server ${registry_url} successfully!"
  fi
}

# 上传镜像 
function push_image() {
  for image in $images;
  do
    echo -e "docker push $image to ${registry_addr}"
    docker tag  ${image} ${registry_addr}/${image}
    docker push ${registry_addr}/${image}
    docker rmi  ${registry_addr}/${image} >/dev/null 2>&1
  done
}

# 下载镜像 
function pull_image() {
  for image in $images;
  do
    echo -e "dokcer pull $image from ${registry_addr}"
    docker pull ${registry_addr}/${image}
    docker tag  ${registry_addr}/${image} ${image}
    docker rmi  ${registry_addr}/${image} >/dev/null 2>&1
  done
}

case "$1" in 
  "-h")
    echo  
    echo "sh $0 -h                                     #帮助"
    echo "sh $0 pull image1:version1 image2:version2   #下载"
    echo "sh $0 push image1:version1 image2:version2   #上传"
    echo
;;
  "pull")
    images=${*/pull/}
    check_registry
    pull_image
;;
  "push")
    images=${*/push/}
    check_registry
    push_image
;;
  *)
    check_registry
;;
esac
