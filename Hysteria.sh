#!/bin/bash

# 检查是否以 root 用户身份运行
if [ "$EUID" -ne 0 ]; then
  echo "请以 root 用户身份运行此脚本"
  exit 1
fi

# 判断系统及定义系统安装依赖方式
DISTRO=$(cat /etc/os-release | grep '^ID=' | awk -F '=' '{print $2}' | tr -d '"')
case $DISTRO in
  "debian"|"ubuntu")
    PACKAGE_UPDATE="apt-get update"
    PACKAGE_INSTALL="apt-get install -y"
    PACKAGE_REMOVE="apt-get remove -y"
    PACKAGE_UNINSTALL="apt-get autoremove -y"
    ;;
  "centos"|"fedora"|"rhel")
    PACKAGE_UPDATE="yum -y update"
    PACKAGE_INSTALL="yum -y install"
    PACKAGE_REMOVE="yum -y remove"
    PACKAGE_UNINSTALL="yum -y autoremove"
    ;;
  *)
    echo "不支持的 Linux 发行版"
    exit 1
    ;;
esac

# 显示选项菜单
echo "请选择一个选项:"
echo "1) 安装 Hysteria2"
echo "2) 卸载 Hysteria2"
read -p "输入选项 (1 或 2): " OPTION

if [ "$OPTION" == "1" ]; then
  # 安装必要的软件包
  $PACKAGE_INSTALL unzip wget curl

  # 一键安装Hysteria2
  bash <(curl -fsSL https://get.hy2.sh/)

  # 生成自签证书
  openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=bing.com" -days 36500
  chown hysteria /etc/hysteria/server.key /etc/hysteria/server.crt

  # 随机生成端口和密码
  RANDOM_PORT=$(shuf -i 2000-65000 -n 1)
  RANDOM_PSK=$(openssl rand -base64 12)

  # 生成配置文件
  cat << EOF > /etc/hysteria/config.yaml
listen: :$RANDOM_PORT # 监听随机端口

# 使用自签证书
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: "$RANDOM_PSK" # 设置随机密码
  
masquerade:
  type: proxy
  proxy:
    url: https://bing.com # 伪装网址
    rewriteHost: true
EOF

  # 启动Hysteria2
  systemctl start hysteria-server.service

  # 设置开机自启
  systemctl enable hysteria-server.service

  # 获取本机IP地址
  HOST_IP=$(curl -s http://checkip.amazonaws.com)

  # 获取IP所在国家
  IP_COUNTRY=$(curl -s http://ipinfo.io/$HOST_IP/country)

  # 输出所需信息，包含IP所在国家
  echo "Hysteria2已安装并启动, 卸载请执行此脚本并选择卸载选项"
  echo "$IP_COUNTRY = hysteria2, $HOST_IP, $RANDOM_PORT, password = $RANDOM_PSK, skip-cert-verify=true, sni=www.bing.com"
  cat << EOF
- name: $IP_COUNTRY
  type: hysteria2
  server: $HOST_IP
  port: $RANDOM_PORT
  password: $RANDOM_PSK
  alpn:
    - h3
  sni: www.bing.com
  skip-cert-verify: true
  fast-open: true
EOF

elif [ "$OPTION" == "2" ]; then
  # 停止并卸载 Hysteria2
  systemctl stop hysteria-server.service
  systemctl disable hysteria-server.service
  rm -f /etc/systemd/system/hysteria-server.service
  rm -rf /etc/hysteria
  bash <(curl -fsSL https://get.hy2.sh/) --remove
  echo "Hysteria2 已卸载"
else
  echo "无效的选项"
  exit 1
fi
