#!/bin/bash
#
##########################################################################
#该脚本适用于ubuntu2004系统
#该脚本中container runtime使用docker
#根据安装的kubernetes的版本不同脚本可自动判断是否安装cri-dockerd,小于1.24版不安装
#cri-dockerd版本可根据kubernetes版本而更新使用新版本
#该脚本CNI网络插件默认安装Flannel
#如果安装Calico,请在安装前修改POD_NETWORK变量和install_cni函数
#选择与当前kubernetes版本兼容的calico发行版
##########################################################################
#

KUBE_VERSION="1.25.5"
#KUBE_VERSION="1.24.4"
#KUBE_VERSION="1.24.3"
#KUBE_VERSION="1.23.6"

KUBE_VERSION2=$(echo $KUBE_VERSION |awk -F . '{print $2}')

KUBEAPI_IP=10.0.0.101
MASTER1_IP=10.0.0.101
MASTER2_IP=10.0.0.102
MASTER3_IP=10.0.0.103
NODE1_IP=10.0.0.104
NODE2_IP=10.0.0.105
NODE3_IP=10.0.0.106
#HARBOR_IP=10.0.0.200

MASTER1=master1
MASTER2=master2
MASTER3=master3
NODE1=node1
NODE2=node2
NODE3=node3
#HARBOR=harbor

POD_NETWORK="10.244.0.0/16"
SERVICE_NETWORK="10.96.0.0/12"

IMAGES_URL="registry.aliyuncs.com/google_containers"

UBUNTU_CODENAME=$(cat /etc/os-release | tail -1 | awk -F = '{print $2}')
CIR_DOCKER_VERSION=0.3.1
CIR_DOCKER_URL="https://github.com/Mirantis/cri-dockerd/releases/download/v${CIR_DOCKER_VERSION}/cri-dockerd_${CIR_DOCKER_VERSION}.3-0.ubuntu-${UBUNTU_CODENAME}_amd64.deb"
CNI_URL="https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

LOCAL_IP=`hostname -I|awk '{print $1}'`

. /etc/os-release

COLOR_SUCCESS="echo -e \\033[1;32m"
COLOR_FAILURE="echo -e \\033[1;31m"
END="\033[m"


color () {
    RES_COL=60
    MOVE_TO_COL="echo -en \\033[${RES_COL}G"
    SETCOLOR_SUCCESS="echo -en \\033[1;32m"
    SETCOLOR_FAILURE="echo -en \\033[1;31m"
    SETCOLOR_WARNING="echo -en \\033[1;33m"
    SETCOLOR_NORMAL="echo -en \E[0m"
    echo -n "$1" && $MOVE_TO_COL
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ] ;then
        ${SETCOLOR_SUCCESS}
        echo -n $"  OK  "    
    elif [ $2 = "failure" -o $2 = "1"  ] ;then 
        ${SETCOLOR_FAILURE}
        echo -n $"FAILED"
    else
        ${SETCOLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${SETCOLOR_NORMAL}
    echo -n "]"
    echo 
}

check () {
    if grep -qs "ubuntu" /etc/os-release; then
        OS="ubuntu"
        OS_VERSION=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    fi
    if [[ $OS = 'ubuntu' && ${OS_VERSION} -eq "2004" ]];then
        ${COLOR_FAILURE}"安装前请确定主机名已修改完成!如果未修改主机名，请按ctrl+c键退出，修改完主机名后再执行脚本"${END}
        sleep 6
        true
    else
        color "不支持此操作系统，退出!" 1
        exit
    fi
}

install_prepare () {
    cat >> /etc/hosts <<EOF
$KUBEAPI_IP kubeapi
$MASTER1_IP $MASTER1
$MASTER2_IP $MASTER2
$MASTER3_IP $MASTER3
$NODE1_IP $NODE1
$NODE2_IP $NODE2
$NODE3_IP $NODE3
$HARBOR_IP $HARBOR
EOF
    #hostnamectl set-hostname $(awk -v ip=$LOCAL_IP '{if($1==ip && $2 !~ "kubeapi")print $2}' /etc/hosts)
    swapoff -a
    sed -i '/swap/s/^/#/' /etc/fstab

    systemctl disable ufw
    systemctl stop ufw

    modprobe -- ip_vs
    modprobe -- ip_vs_rr
    modprobe -- ip_vs_wrr
    modprobe -- ip_vs_sh
    lsmod|grep ip_vs

    modprobe br_netfilter
    modprobe nf_conntrack
    cat > /etc/sysctl.d/kubernetes.conf <<EOF
net.netfilter.nf_conntrack_tcp_be_liberal = 1
net.netfilter.nf_conntrack_tcp_loose = 1
net.netfilter.nf_conntrack_max = 524288
net.netfilter.nf_conntrack_buckets = 131072
net.netfilter.nf_conntrack_tcp_timeout_established = 21600
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh3 = 4096
vm.max_map_count = 262144
net.ipv4.ip_forward = 1
net.ipv4.tcp_timestamps = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv6.conf.all.forwarding=1
fs.file-max=1048576
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288
EOF
    sysctl -p /etc/sysctl.d/kubernetes.conf

    cat > /etc/security/limits.d/kubernetes.conf << EOF
* soft nproc 65535
* hard nproc 65535
* soft nofile 65535
* hard nofile 65535
EOF

    timedatectl set-timezone Asia/Shanghai
    timedatectl set-local-rtc 0
    systemctl restart rsyslog 

    cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ focal-security main restricted universe multiverse
EOF
    apt-get update
    color "安装前准备完成!" 0
    sleep 5
}

install_docker () {
    apt update
    apt -y install docker.io || { color "安装Docker失败!" 1; exit 1; }
    cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"], 
  "registry-mirrors": ["https://fl7idj1l.mirror.aliyuncs.com"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  } 
}

EOF
    systemctl daemon-reload && systemctl restart docker.service
    docker info && { color "安装Docker成功!" 0; sleep 1; } || { color "安装Docker失败!" 1 ; exit 2; }
    sleep 5
}

install_kubeadm () {
    apt-get update && apt-get install -y apt-transport-https
    curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - 
    cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
EOF
    apt-get update
    apt-cache madison kubeadm |head
    ${COLOR_FAILURE}"5秒后即将安装: kubeadm-"${KUBE_VERSION}" 版本....."${END}
    ${COLOR_FAILURE}"如果想安装其它版本，请按ctrl+c键退出，修改版本再执行"${END}
    sleep 6

    #安装指定版本
    apt install -y  kubeadm=${KUBE_VERSION}-00 kubelet=${KUBE_VERSION}-00 kubectl=${KUBE_VERSION}-00
    [ $? -eq 0 ] && { color "安装kubeadm成功!" 0;sleep 1; } || { color "安装kubeadm失败!" 1 ; exit 2; }
    
    #实现kubectl命令自动补全功能    
    kubectl completion bash > /etc/profile.d/kubectl_completion.sh
    sleep 5
}

#Kubernetes-v1.24之前版本无需安装cri-dockerd
install_cri_dockerd () {
    [ $KUBE_VERSION2 -lt 24 ] && return
    if [ ! -e cri-dockerd_${CIR_DOCKER_VERSION}.3-0.ubuntu-${UBUNTU_CODENAME}_amd64.deb ];then
        curl -LO $CIR_DOCKER_URL || { color "下载cri-dockerd失败!" 1 ; exit 2; }
    fi
    dpkg -i cri-dockerd_${CIR_DOCKER_VERSION}.3-0.ubuntu-${UBUNTU_CODENAME}_amd64.deb 
    [ $? -eq 0 ] && color "安装cri-dockerd成功!" 0 || { color "安装cri-dockerd失败!" 1 ; exit 2; }
    sed -i '/^ExecStart/s#$# --pod-infra-container-image registry.aliyuncs.com/google_containers/pause:3.7#'   /lib/systemd/system/cri-docker.service
    systemctl daemon-reload 
    systemctl restart cri-docker.service
    [ $? -eq 0 ] && { color "配置cri-dockerd成功!" 0 ; sleep 1; } || { color "配置cri-dockerd失败!" 1 ; exit 2; }
    sleep 5
}

#只有Kubernetes集群的第一个master节点需要执行下面初始化函数
kubernetes_init () {
    if [ $KUBE_VERSION2 -lt 24 ] ;then
        kubeadm init --control-plane-endpoint="kubeapi" \
                 --kubernetes-version=v${KUBE_VERSION}  \
                 --pod-network-cidr=${POD_NETWORK} \
                 --service-cidr=${SERVICE_NETWORK} \
                 --token-ttl=0  \
                 --upload-certs \
                 --image-repository=${IMAGES_URL} | tee  kubeadm-init.log
    else
    #Kubernetes-v1.24版本前无需加选项 --cri-socket=unix:///run/cri-dockerd.sock
        kubeadm init --control-plane-endpoint="kubeapi" \
                 --kubernetes-version=v${KUBE_VERSION}  \
                 --pod-network-cidr=${POD_NETWORK} \
                 --service-cidr=${SERVICE_NETWORK} \
                 --token-ttl=0  \
                 --upload-certs \
                 --image-repository=${IMAGES_URL} \
                 --cri-socket=unix:///run/cri-dockerd.sock | tee  kubeadm-init.log
    fi
    [ $? -eq 0 ] && color "Kubernetes集群初始化成功!" 0 || { color "Kubernetes集群初始化失败!" 1 ; exit 3; }
    mkdir -p $HOME/.kube
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
    sleep 5
}

install_cni() {
    if [ ! -e kube-flannel.yml ];then
        wget $CNI_URL || { color "下载kube-flannel.yml失败!" 1 ; exit 2; }
    fi
        kubectl create -f kube-flannel.yml 
    [ $? -eq 0 ] && color "安装网络插件Flannel成功!" 0 || { color "安装网络插件Flannel失败!" 1 ; exit 2; }
}

reset_kubernetes() {
    kubeadm reset -f --cri-socket unix:///run/cri-dockerd.sock
    rm -rf  /etc/cni/net.d/  $HOME/.kube/config
}


check 

PS3="请选择编号(1-4): "
ACTIONS="
初始化新的Kubernetes集群
加入已有的Kubernetes集群
退出Kubernetes集群
退出本程序
"
select action in $ACTIONS;do
    case $REPLY in 
    1)
        install_prepare
        install_docker
        install_kubeadm
        install_cri_dockerd
        kubernetes_init
        install_cni
        break
        ;;
    2)
        install_prepare
        install_docker
        install_kubeadm
        install_cri_dockerd
        $COLOR_SUCCESS"加入已有的Kubernetes集群已准备完毕,还需要执行最后一步加入集群的命令 kubeadm join !"${END}
        break
        ;;
    3)
        reset_kubernetes
        break
        ;;
    4)
        exit
        ;;
    esac
done

