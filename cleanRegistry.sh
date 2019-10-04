#!/bin/bash

# CentOS7.5 Minimal,docker-ce v18.06.0,registry v2.7.1
# Docker registry 私有仓库镜像查询、删除、上传、下载

# Author  Michael <user@example.com>


# 参数 variable
# image="image_name:image_version"

# registry容器名称,默认registry
registry_name="registry"
registry_name=${registry_name:-registry}

# 访问仓库地址：xx.xx.xx.xx:443
registry_url="https://192.168.1.105:443"

# auth 认证用户名密码
auth_user="test"
auth_passwd="Test@123"

# Script run root
if [[ $UID -ne 0 ]]; then
   echo "This script must be run as root."
   exit 1
fi

# Command-line JSON processor
if [[ ! -f /usr/bin/jq ]]; then
  echo "Install jq"
  yum -y install jq > /dev/null 2>&1
fi

# 检测仓库的可用性
function check_registry() {
  curl -s -u ${auth_user}:${auth_passwd} ${registry_url}/v2/_catalog > /dev/null 2>&1 
  if [ $? -eq 0 ]; then
    echo -e "Connect to registry server ${registry_url} successfully!"
  else
    echo -e "Connect to registry server ${registry_url} failed!"
    exit 1
  fi
}

# 获取镜像和对应版本名列表
function fetch_image_name_version() {
  image_name_list=$(curl -s -u ${auth_user}:${auth_passwd} ${registry_url}/v2/_catalog | jq .repositories | awk -F'"' '{for(i=1;i<=NF;i+=2)$i=""}{print $0}')
  if [[ ${image_name_list} = "" ]]; then
    echo -e "No image found in ${registry_url}!"
    exit 1
  fi

  for image_name in ${image_name_list};
    do
      image_version_list=$(curl -s -u ${auth_user}:${auth_passwd} ${registry_url}/v2/$image_name/tags/list | jq .tags | awk -F'"' '{for(i=1;i<=NF;i+=2)$i=""}{print $0}')
      for t in $image_version_list;
      do
        echo "${image_name}:${t}"
      done
    done
}

# 删除镜像
function delete_image() {
  for n in ${images};
  do
    image_name=${n%%:*}
    image_version=${n##*:}
    i=1
    [[ "${image_name}" == "${image_version}" ]] && { image_version=latest; n="$n:latest"; }

    image_digest=`curl -u ${auth_user}:${auth_passwd} --header "Accept: application/vnd.docker.distribution.manifest.v2+json" -Is  ${registry_url}/v2/${image_name}/manifests/${image_version} | awk '/Digest/ {print $NF}'`

    if [[ -z "${image_digest}" ]]; then
      echo -e "${image_name}:${image_version} does no exist!" 
    else  
      digest_url="${registry_url}/v2/${image_name}/manifests/${image_digest}"
      return_code=$(curl -Is -u ${auth_user}:${auth_passwd} -X DELETE ${digest_url%?} | awk '/HTTP/ {print $2}')
      if [[ ${return_code} -eq 202 ]]; then
        echo "Delete $n successfully!"
        let i++
      else
        echo -e "Delete $n failed!"
      fi
    fi
  done
# registry垃圾回收 
   if [[ "$i" -gt 1 ]]; then
     echo "Clean..."
     docker exec ${registry_name} registry garbage-collect /etc/docker/registry/config.yml
     # docker stop ${registry_name} && docker start ${registry_name}
     systemctl restart ${registry_name}
   fi
}

# 删除同仓库中一个镜像的所有版本
function delete_all_image() {
  [[ -f /usr/bin/docker ]] || echo "No docker client found."
  [[ -z $(docker ps |awk '/'${registry_name}'/ {print $NF}') ]] && { echo "${registry_name} container does no exist.";exit; }
  for n in ${images};
  do
    image_name="${n%%:*}"
    docker exec ${registry_name} rm -rf /var/lib/registry/docker/registry/v2/repositories/${image_name}
  done

  echo "Clean..."
  docker exec ${registry_name} registry garbage-collect /etc/docker/registry/config.yml 
  # docker stop ${registry_name} && docker start ${registry_name}
  systemctl restart ${registry_name}
}

case "$1" in
  "-h")
  echo
  echo "#默认查询所有 镜像名:版本号"
  echo "sh $0 -h                                                           #帮助"
  echo "sh $0 -d image_name1:image_version1 image_name2_image_version2     #删除"
  echo "sh $0 -dd  image_name                                              #清理"
  echo
  echo "#示例：删除 centos:6 centos:7 (镜像名:版本)"
  echo "sh $0 -d centos:6  centos:7"
  echo "#示例：删除centos所有版本"
  echo "sh $0 -dd centos"
  echo
;;
  "-d")
  check_registry
  images=${*/-dd/}
  images=${images/-d/}
  delete_image
;;
  "-dd")
  check_registry
  images=${*/-dd/}
  images=${images/-d/}
  delete_all_image
;;
  "-q")
  check_registry
  fetch_image_name_version
;;
  *)
  echo "Error command"
;;
esac

