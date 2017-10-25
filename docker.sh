#!/bin/bash
# reqires: wget, yum-utils

set -e
set -o pipefail

_here=`dirname $(realpath $0)`
. ${_here}/helpers/apt-download
APT_VERSIONS=("debian-wheezy" "debian-jessie" "debian-stretch" "ubuntu-precise" "ubuntu-trusty" "ubuntu-xenial")

BASE_PATH="${TUNASYNC_WORKING_DIR}"
APT_PATH="${BASE_PATH}/apt/repo"
YUM_PATH="${BASE_PATH}/yum/repo"

mkdir -p ${APT_PATH} ${YUM_PATH}

wget -q -N -O ${BASE_PATH}/yum/gpg https://yum.dockerproject.org/gpg
wget -q -N -O ${BASE_PATH}/apt/gpg https://apt.dockerproject.org/gpg

# YUM mirror
cache_dir="/tmp/yum-docker-cache/"
cfg="/tmp/docker-yum.conf"
cat <<EOF > ${cfg}
[main]
keepcache=0

[centos6]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/6
enabled=1
gpgcheck=0
gpgkey=https://yum.dockerproject.org/gpg
sslverify=0

[centos7]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7
enabled=1
gpgcheck=0
gpgkey=https://yum.dockerproject.org/gpg
sslverify=0
EOF

[ ! -d ${YUM_PATH}/centos6 ] && mkdir -p ${YUM_PATH}/centos6
[ ! -d ${YUM_PATH}/centos7 ] && mkdir -p ${YUM_PATH}/centos7

if [[ -z ${DRY_RUN:-} ]]; then
	reposync -c $cfg -d -p ${YUM_PATH}  -e $cache_dir
	createrepo --update -v -c $cache_dir -o ${YUM_PATH}/centos6 ${YUM_PATH}/centos7
	createrepo --update -v -c $cache_dir -o ${YUM_PATH}/centos7 ${YUM_PATH}/centos7
fi
rm $cfg

# APT mirror 
if [[ ! -z ${DRY_RUN:-} ]]; then
	export APT_DRY_RUN=1
fi

base_url="https://apt.dockerproject.org/repo"
remote_filelist="${APT_PATH}/filelist"
[[ -f $remote_filelist ]] && rm $remote_filelist

for version in ${APT_VERSIONS[@]}; do
	apt-download-binary ${base_url} "$version" "main" "amd64" "${APT_PATH}" ${remote_filelist} || true
	apt-download-binary ${base_url} "$version" "main" "i386" "${APT_PATH}"  ${remote_filelist} || true
	apt-download-binary ${base_url} "$version" "main" "armhf" "${APT_PATH}"  ${remote_filelist} || true
done

apt-delete-old-debs ${APT_PATH} $remote_filelist

# sync_docker "http://apt.dockerproject.org/" "${TUNASYNC_WORKING_DIR}/apt"
# sync_docker "http://yum.dockerproject.org/" "${TUNASYNC_WORKING_DIR}/yum"
