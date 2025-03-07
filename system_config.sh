#!/bin/bash
# Description: 系统配置脚本（静态IP/Yum源/NTP同步）
# Author: Your Name
# Date: $(date +%F)

# 检查root权限
if [ $EUID -ne 0 ]; then
    echo -e "\033[31m错误：必须使用root用户执行此脚本\033[0m"
    exit 1
fi

# 定义颜色
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

# 配置静态网络
config_static_ip() {
    echo -e "${YELLOW}=== 开始配置静态网络 ===${RESET}"
    
    # 获取可用网卡
    interfaces=($(ls /sys/class/net | grep -v lo))
    echo "可用网络接口:"
    for i in "${!interfaces[@]}"; do
        echo "$((i+1)). ${interfaces[$i]}"
    done

    read -p "请选择网络接口序号 [1-${#interfaces[@]}]: " num
    interface=${interfaces[$((num-1))]}

    read -p "输入IP地址（示例：192.168.1.100）: " ip
    read -p "输入子网掩码（示例：24）: " prefix
    read -p "输入网关地址（示例：192.168.1.1）: " gateway
    read -p "输入DNS服务器（示例：223.5.5.5）: " dns

    # 备份原配置
    cfg_file="/etc/sysconfig/network-scripts/ifcfg-${interface}"
    cp "$cfg_file" "${cfg_file}.bak"

    # 生成新配置
    cat > "$cfg_file" << EOF
TYPE=Ethernet
BOOTPROTO=static
NAME=${interface}
DEVICE=${interface}
ONBOOT=yes
IPADDR=${ip}
PREFIX=${prefix}
GATEWAY=${gateway}
DNS1=${dns}
EOF

    nmcli connection reload
    nmcli connection down "${interface}" && nmcli connection up "${interface}"
    echo -e "${GREEN}网络配置完成${RESET}"
}

# 更换yum源
change_yum_source() {
    echo -e "${YELLOW}=== 开始更换阿里云Yum源 ===${RESET}"
    mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
    
    # 自动获取系统版本
    releasever=$(rpm -E %{rhel})
    
    curl -o /etc/yum.repos.d/CentOS-Base.repo \
        https://mirrors.aliyun.com/repo/Centos-${releasever}.repo
    
    sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo
    yum clean all
    yum makecache
    echo -e "${GREEN}Yum源更换完成${RESET}"
}

# 配置时间同步
config_ntp() {
    echo -e "${YELLOW}=== 开始配置时间同步 ===${RESET}"
    yum install -y chrony
    
    # 备份原配置
    cp /etc/chrony.conf /etc/chrony.conf.bak
    
    # 使用阿里云NTP服务器
    cat > /etc/chrony.conf << EOF
server ntp.aliyun.com iburst
server time1.cloud.tencent.com iburst
driftfile /var/lib/chrony/drift
makestep 1.0 3
rtcsync
logdir /var/log/chrony
EOF

    systemctl enable chronyd --now
    timedatectl set-timezone Asia/Shanghai
    chronyc sources -v
    echo -e "${GREEN}时间同步配置完成${RESET}"
}

# 执行主函数
main() {
    config_static_ip
    change_yum_source
    config_ntp
    echo -e "${GREEN}\n所有配置已完成，建议重启系统！${RESET}"
}

main
