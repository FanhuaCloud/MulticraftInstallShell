#!/bin/bash

function Colorset() {
  #颜色配置
  echo=echo
  for cmd in echo /bin/echo; do
    $cmd >/dev/null 2>&1 || continue
    if ! $cmd -e "" | grep -qE '^-e'; then
      echo=$cmd
      break
    fi
  done
  CSI=$($echo -e "\033[")
  CEND="${CSI}0m"
  CDGREEN="${CSI}32m"
  CRED="${CSI}1;31m"
  CGREEN="${CSI}1;32m"
  CYELLOW="${CSI}1;33m"
  CBLUE="${CSI}1;34m"
  CMAGENTA="${CSI}1;35m"
  CCYAN="${CSI}1;36m"
  CSUCCESS="$CDGREEN"
  CFAILURE="$CRED"
  CQUESTION="$CMAGENTA"
  CWARNING="$CYELLOW"
  CMSG="$CCYAN"
}

function Logprefix() {
  #输出log
  echo -n ${CGREEN}'CraftYun >> '
}

function Checksystem() {
  cd
  Logprefix;echo ${CMSG}'[Info]检查系统'${CEND}
  #检查系统
  if [[ $(id -u) != '0' ]]; then
    Logprefix;echo ${CWARNING}'[Error]请使用root用户安装!'${CEND}
    exit
  fi

  if grep -Eqii "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
    DISTRO='CentOS'
  else
    DISTRO='unknow'
  fi

  if [[ ${DISTRO} == 'unknow' ]]; then
    Logprefix;echo ${CWARNING}'[Error]请使用Centos系统安装!'${CEND}
    exit
  fi

  if grep -Eqi "release 5." /etc/redhat-release; then
      RHEL_Version='5'
  elif grep -Eqi "release 6." /etc/redhat-release; then
      RHEL_Version='6'
  elif grep -Eqi "release 7." /etc/redhat-release; then
      RHEL_Version='7'
  fi

  if [[ ${RHEL_Version} != '7' ]]; then
    Logprefix;echo ${CWARNING}'[Error]请使用Centos7安装!'${CEND}
    exit
  fi

  if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
      OS_Bit='64'
  else
      OS_Bit='32'
  fi

  if [[ ${OS_Bit} == '32' ]]; then
    Logprefix;echo ${CWARNING}'[Error]请使用64位Centos7!'${CEND}
    exit
  fi
}

function Closefirewalld() {
  #关闭防火墙
  Logprefix;echo ${CMSG}'[Info]关闭防火墙'${CEND}
  systemctl stop firewalld.service #停止firewall
  systemctl disable firewalld.service #禁止firewall开机启动
}

function Coloseselinux() {
  #关闭selinux
  Logprefix;echo ${CMSG}'[Info]关闭Selinux'${CEND}
  [ -s /etc/selinux/config ] && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0 >/dev/null 2>&1
}

function Settimezone() {
  #设置时区并同步时间
  Logprefix;echo ${CMSG}'[Info]设置服务器时区'${CEND}
  rm -rf /etc/localtime
	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
  Logprefix;echo ${CMSG}'[Info]同步服务器时间'${CEND}
  ntpdate cn.ntp.org.cn
}

function Setlocale() {
  #设置语言
  Logprefix;echo ${CMSG}'[Info]设置服务器语言(重新登录生效)'${CEND}
  localectl  set-locale LANG=zh_CN.utf8
}

function Yumupdate() {
  #升级系统软件
  Logprefix;echo ${CMSG}'[Info]升级系统软件,可能需要花费较长时间，请耐心等待'${CEND}
  yum -y update
}

function Installbasesoftware() {
  #安装基础软件
  Logprefix;echo ${CMSG}'[Info]安装基础软件'${CEND}
  Logprefix;echo ${CMSG}'[Info]安装epel源'${CEND}
  yum -y install epel-release
  Logprefix;echo ${CMSG}'[Info]安装wget'${CEND}
  yum -y install wget
  Logprefix;echo ${CMSG}'[Info]安装lrzsz'${CEND}
  yum -y install lrzsz
  Logprefix;echo ${CMSG}'[Info]安装zip unzip'${CEND}
  yum -y install unzip zip
  Logprefix;echo ${CMSG}'[Info]安装Development Tools'${CEND}
  yum -y groupinstall "Development Tools"
  Logprefix;echo ${CMSG}'[Info]安装JDK'${CEND}
  yum -y install java-1.7.0-openjdk
  yum -y install java-1.8.0-openjdk
}

function Askuser() {
  #询问用户信息
  ASK_PANEL_NAME=$(whiptail --title "提示" --inputbox "请输入面板标题" 10 60 繁花云 3>&1 1>&2 2>&3)

  RandomValue=$RANDOM
  IPAddress=`ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\." | head -n 1`;
  StartDate=$(date);
  DefaultPassword=`echo -n "${IPAddress}_${RandomValue}_$(date)" | md5sum | sed "s/ .*//" | cut -b -12`

  Logprefix;echo ${CMSG}'[Info]提示:您的初始MYSQL密码为'${DefaultPassword}${CEND}
  Logprefix;echo ${CMSG}'[Info]提示:您的初始DAEMON密码为'${DefaultPassword}${CEND}
  Logprefix;echo ${CMSG}'[Info]提示:您的面板标题为'${ASK_PANEL_NAME}${CEND}

  ASK_MYSQL_PASS=${DefaultPassword}
  ASK_DAEMON_PASS=${DefaultPassword}

  Logprefix;echo ${CMSG}'[Info]提示:按下回车键开始，或使用CTRL+C退出'${CEND}
  read
}

function Installlamp() {
  #安装环境
  Logprefix;echo ${CMSG}'[Info]安装LAMP环境'${CEND}
  Logprefix;echo ${CMSG}'[Info]安装HTTPD(APACHE)'${CEND}
  yum -y install httpd
  Logprefix;echo ${CMSG}'[Info]安装MARRIDB(MYSQL)'${CEND}
  yum -y install mariadb mariadb-server
  Logprefix;echo ${CMSG}'[Info]安装PHP基础'${CEND}
  yum -y install php
  Logprefix;echo ${CMSG}'[Info]安装PHP扩展'${CEND}
  yum -y install php-mysql php-gd libjpeg* php-ldap php-odbc php-pear php-xml php-xmlrpc php-mbstring php-bcmath php-mhash php-opcache
}

function Configurelamp() {
  #配置LAMP
  Logprefix;echo ${CMSG}'[Info]配置LAMP'${CEND}
  Logprefix;echo ${CMSG}'[Info]配置APACHE'${CEND}
  rm -rf /etc/httpd/conf.d/welcome.conf
  echo 'Listen 8080' >> /etc/httpd/conf/httpd.conf
  echo '<VirtualHost *:8080>
    ServerAdmin admin@example.com
    DocumentRoot "/home/wwwroot/panel"
    <Directory "/home/wwwroot/panel">
      SetOutputFilter DEFLATE
      Options FollowSymLinks ExecCGI
      Require all granted
      AllowOverride All
      Order allow,deny
      Allow from all
      DirectoryIndex index.html index.php
    </Directory>
  </VirtualHost>' > /etc/httpd/conf.d/vhost.conf
  systemctl start httpd.service
  systemctl enable httpd.service
  Logprefix;echo ${CMSG}'[Info]配置MYSQL'${CEND}
  rm -rf /etc/my.cnf
  cp /usr/share/mysql/my-huge.cnf /etc/my.cnf
  systemctl start mariadb.service
  systemctl enable mariadb.service
  #设置MYSQl密码
  mysqladmin -u root password ${ASK_MYSQL_PASS}
}

function Installmulticraft() {
  #安装Multicraft
  Logprefix;echo ${CMSG}'[Info]安装Multicraft'${CEND}
  Logprefix;echo ${CMSG}'[Info]下载Multicraft安装包'${CEND}
  wget http://coredlserver.s-api.yunvm.com/shell/multicraft-2.1.1-64.tar.gz -O /root/multicraft-2.1.1-64.tar.gz
  tar -xvf /root/multicraft-2.1.1-64.tar.gz
  Logprefix;echo ${CMSG}'[Info]配置Multicraft'${CEND}
  cd /root/multicraft
  #生成应答文件
  echo '
  declare -x MC_CREATE_USER="y"
  declare -x MC_DAEMON_ID="1"
  declare -x MC_DAEMON_PW="{ASK_DAEMON_PASS}"
  declare -x MC_DB_HOST="127.0.0.1"
  declare -x MC_DB_NAME="multicraft_daemon"
  declare -x MC_DB_PASS="{ASK_MYSQL_PASS}"
  declare -x MC_DB_TYPE="mysql"
  declare -x MC_DB_USER="root"
  declare -x MC_DIR="/home/minecraft/multicraft"
  declare -x MC_FTP_IP="0.0.0.0"
  declare -x MC_FTP_PORT="21"
  declare -x MC_FTP_SERVER="y"
  declare -x MC_KEY="677D-3C64-8B93-BFFC"
  declare -x MC_LOCAL="y"
  declare -x MC_MULTIUSER="y"
  declare -x MC_PLUGINS="n"
  declare -x MC_USER="minecraft"
  declare -x MC_WEB_DIR="/home/wwwroot/panel"
  declare -x MC_WEB_USER="apache"
  ' > /root/multicraft/setup.config

  sed -i "s/{ASK_DAEMON_PASS}/${ASK_DAEMON_PASS}/g" /root/multicraft/setup.config
  sed -i "s/{ASK_MYSQL_PASS}/${ASK_MYSQL_PASS}/g" /root/multicraft/setup.config

  #执行安装脚本
  bash -c "$(curl -sS http://coredlserver.s-api.yunvm.com/shell/setup.sh)"
  cd

  Logprefix;echo ${CMSG}'[Info]安装网页端'${CEND}
  rm -rf /home/wwwroot/panel/install.php
  wget http://coredlserver.s-api.yunvm.com/config.php -O /home/wwwroot/panel/protected/config/config.php
  chmod 640 /home/wwwroot/panel/protected/config/config.php
  chown apache:apache /home/wwwroot/panel/protected/config/config.php
  sed -i "s/{ASK_DAEMON_PASS}/${ASK_DAEMON_PASS}/g" /home/wwwroot/panel/protected/config/config.php
  sed -i "s/{ASK_MYSQL_PASS}/${ASK_MYSQL_PASS}/g" /home/wwwroot/panel/protected/config/config.php

  Logprefix;echo ${CMSG}'[Info]创建数据库'${CEND}

  # 导入数据库
  mysql -uroot -p${ASK_MYSQL_PASS} -e "create database multicraft_panel"
  mysql -uroot -p${ASK_MYSQL_PASS} -e "create database multicraft_daemon"

  Logprefix;echo ${CMSG}'[Info]导入数据库'${CEND}

  mysql -uroot -p${ASK_MYSQL_PASS} multicraft_panel -e "source /home/wwwroot/panel/protected/data/panel/schema.mysql.sql"
  mysql -uroot -p${ASK_MYSQL_PASS} multicraft_daemon -e "source /home/wwwroot/panel/protected/data/daemon/schema.mysql.sql"

  # 破解
  Logprefix;echo ${CMSG}'[Info]破解Multicraft'${CEND}
  rm -rf /home/minecraft/multicraft/bin/multicraft
  wget http://coredlserver.s-api.yunvm.com/shell/multicraft -O /home/minecraft/multicraft/bin/multicraft
  chmod 755 /home/minecraft/multicraft/bin/multicraft
  chown minecraft:minecraft /home/minecraft/multicraft/bin/multicraft

  Logprefix;echo ${CMSG}'[Info]删除安装包'${CEND}
  rm -rf /root/multicraft /root/multicraft-2.1.1-64.tar.gz
}

function Installok() {
  #安装完成提示
  /home/minecraft/multicraft/bin/multicraft -v start
  Logprefix;echo ${CMAGENTA}'[Success]安装完成'${CEND}
  Logprefix;echo ${CMAGENTA}'[Success]DAEMON密码:'${ASK_DAEMON_PASS}${CEND}
  Logprefix;echo ${CMAGENTA}'[Success]MYSQL密码'${ASK_MYSQL_PASS}${CEND}
  Logprefix;echo ${CMAGENTA}'[Success]请使用IP:8080访问面板进行进一步配置'${CEND}
  Logprefix;echo ${CMAGENTA}'[Success]重启面板/home/minecraft/multicraft/bin/multicraft -v restart'${CEND}
}

function Installotherfile() {
  #安装附加文件
  # ocp.php phpmyadmin 中文语言包
  mkdir -p /home/wwwroot/panel/control/
  Logprefix;echo ${CMSG}'[Info]下载ocp.php'${CEND}
  wget http://coredlserver.s-api.yunvm.com/shell/ocp.php -O /home/wwwroot/panel/control/ocp.php
  Logprefix;echo ${CMSG}'[Info]下载PhpMyadmin'${CEND}
  wget http://coredlserver.s-api.yunvm.com/shell/phpMyAdmin.zip -O /home/wwwroot/panel/control/phpMyAdmin.zip
  unzip /home/wwwroot/panel/control/phpMyAdmin.zip -d /home/wwwroot/panel/control/
  rm -rf /home/wwwroot/panel/control/phpMyAdmin.zip
  chmod -R 750 /home/wwwroot/panel/control
  chown -R apache:apache /home/wwwroot/panel/control
  Logprefix;echo ${CMSG}'[Info]下载中文语言包'${CEND}
  wget http://coredlserver.s-api.yunvm.com/shell/zh.inc.php -O /home/wwwroot/panel/protected/extensions/net2ftp/languages/zh.inc.php
  wget http://coredlserver.s-api.yunvm.com/shell/zh.tar.gz -O /home/wwwroot/panel/protected/messages/zh.tar.gz
  tar zxvf /home/wwwroot/panel/protected/messages/zh.tar.gz -C /home/wwwroot/panel/protected/messages/
  rm -rf /home/wwwroot/panel/protected/messages/zh.tar.gz
  chmod -R 750 /home/wwwroot/panel/protected/messages/zh
  chown -R apache:apache /home/wwwroot/panel/protected/messages/zh
  Logprefix;echo ${CMSG}'[Info]下载核心包'${CEND}
  rm -rf /home/minecraft/multicraft/jar/*
  wget http://coredlserver.s-api.yunvm.com/shell/pccore.zip -O /home/minecraft/multicraft/jar/pccore.zip
  unzip /home/minecraft/multicraft/jar/pccore.zip -d /home/minecraft/multicraft/jar/
  chmod -R 755 /home/minecraft/multicraft/jar/*
  chown -R minecraft:minecraft /home/minecraft/multicraft/jar/*
}

Colorset
Checksystem

Closefirewalld
Coloseselinux
Settimezone
Setlocale
Installbasesoftware
Yumupdate

#安装开始
Askuser
Installlamp
Configurelamp
Installmulticraft
Installotherfile
Installok
