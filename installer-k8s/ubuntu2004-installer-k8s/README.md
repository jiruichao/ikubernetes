# 在线安装kubernetes脚本使用说明：

# 配置节点IP地址变量：
# 1. KUBE_VERSION 需要安装的kubernetes的版本
# 2. KUBEAPI_IP schedulerendpoint的IP
# 3. MASTER1_IP 第1个master节点的IP
# 4. MASTER2_IP 第2个master节点的IP
# 5. MASTER3_IP 第3个master节点的IP
# 6. NODE1_IP 第1个node节点的IP
# 7. NODE2_IP 第2个node节点的IP
# 8. NODE3_IP 第3个node节点的IP
# 9. NODE*_IP 如果有更多的node节点可继续配置node ip地址的变量
# 10. HARBOR_IP harbor仓库地址的IP，默认是注释不生效的，如需配置使用harbor仓库可开启配置该变量的值

# 配置节点主机名变量：
# 1. MASTER1 第1个master节点的主机名
# 2. MASTER2 第2个master节点的主机名
# 3. MASTER3 第3个master节点的主机名
# 4. NODE1 第1个node节点的主机名
# 5. NODE2 第1个node节点的主机名
# 6. NODE3 第1个node节点的主机名
# 7. NODE* 如果有更多的node节点可继续配置node节点的主机名
# 8. HARBOR harbor仓库的主机名，默认是注释不生效的，如需配置使用harbor仓库可开启配置该变量的值

# 安装前说明：
# 1. CNI默认使用flannel,flannel部署的yaml文件在k8s部署脚本同级目录存在，安装前请先执行文件重命名命令：mv kube-flannel-v*.**.*.yaml kube-flannel.yaml
#    如果规划使用其他CNI插件可注释掉脚本中的install_cni函数，在初始化前修改脚本内的POD_NETWORK变量，不修改默认pod网络默认使用10.244.0.0/16网络
#    在初始化完后可第一个master节点后自行安装CNI，如可自行安装calico网络组件
# 2. 只需要在第一个master节点选择：1 初始化新的Kubernetes集群
# 3. 其他节点（master或node）选择：2 加入已有的Kubernetes集群
# 4. 最后在除了第一个master节点的其他节点执行加入集群的命令kubeadm join即可，初始化的输出信息将会保留在当前目录的kubeadm-init.log文件中备份，以便于后续使用




