#!/bin/bash
# Desc: CentOS7最小化安装后基础配置工具
# Author: YourName
# 功能：静态IP/SSH/Yum源/时间同步/安全基础设置

# 检查root权限
if [ $(id -u) != "0" ]; then
    echo -e "\033[31m错误：必须使用root用户执行此脚本！\033[0m"
    exit 1
fi

# 获取默认网卡名称（适配多网卡环境）
NIC_NAME=$(ls /sys/class/net | grep -E 'ens|eth' | head -n 1)
[ -z "$NIC_NAME" ] && NIC_NAME="ens33"

# ---------- 静态网络配置 ----------
echo -e "\033[36m[1/5] 配置静态网络...\033[0m"
cat > /etc/sysconfig/network-scripts/ifcfg-$NIC_NAME << EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=$NIC_NAME
DEVICE=$NIC_NAME
ONBOOT=yes
IPADDR=192.168.1.100
NETMASK=255.255.255.0
GATEWAY=192.168.1.1
DNS1=8.8.8.8
DNS2=114.114.114.114
EOF

systemctl restart network
echo -e "网络状态检查："
ip addr show $NIC_NAME | grep 'inet '

# ---------- SSH服务配置 ----------
echo -e "\033[36m[2/5] 配置SSH服务...\033[0m"
yum install -y openssh-server > /dev/null 2>&1
systemctl start sshd
systemctl enable sshd

# ---------- Yum源优化 ----------
echo -e "\033[36m[3/5] 更换阿里云Yum源...\033[0m"
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
curl -s -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
yum clean all > /dev/null
yum makecache > /dev/null

# ---------- 时间同步 ----------
echo -e "\033[36m[4/5] 配置时间同步...\033[0m"
yum install -y chrony > /dev/null 2>&1
systemctl start chronyd
systemctl enable chronyd
chronyc -a makestep > /dev/null 2>&1

# ---------- 安全基础设置 ----------
echo -e "\033[36m[5/5] 基础安全设置...\033[0m"
systemctl stop firewalld
systemctl disable firewalld
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

# ---------- 完成提示 ----------
echo -e "\033[32m\n✅ 全部配置完成！\033[0m"
echo -e "请用Xshell连接IP：\033[33m$(hostname -I | awk '{print $1}')\033[0m"
echo -e "更多教程请关注公众号【开发者星系】"
