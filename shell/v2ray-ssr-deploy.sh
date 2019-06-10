#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 提示颜色
red="\033[31m"
none="\033[0m"
yellow="\033[33m"
title="\033[42;37m"
button="\033[47;30m"
green="\033[32m"

# 配置默认值
# V2Ray
V2ray_Port="10086"
V2ray_Ssrpanel_Port="10087"
V2ray_Domain=":80 :443"
V2ray_Path="hello"
V2ray_Alter_Id="16"
V2ray_Transfer_Ratio=1
# 数据库
Db_Host="127.0.0.1"
Db_Name="ssrpanel"
Db_User="ssrpanel"
Db_Port="3306"
Db_Password="ssrpanel"
Node_Id="1"
# SSR
Ss_Protocol="origin"
Ss_Obfs="plain"
Ss_Method="none"
Ss_Single_Port_Enable="false"
Ss_Single_Port="8080"
Ss_Password="hello"
Ss_Online_Limit=""
Ss_Speed_Limit="0"

# 提示信息
prompt_info="${green}[Info]${none}"
prompt_warning="${yellow}[Warning]${none}"
prompt_error="${red}[Error]${none}"

pre_config_status=0
notification_level=" 1>/dev/null 2>/dev/null"

[ $(id -u) != "0" ] && { echo -e "${prompt_error}错误: 请以root权限运行"; exit 1; }
sys_bit=$(uname -m)
if [[ -f `which yum` ]]; then
	cmd="yum"
elif [[ -f `which apt` ]]; then
	cmd="apt"
else
	echo -e "${prompt_error}错误: 本脚本只支持CentOS7+及Ubuntu14+" && exit 1
fi

#=========== 组件 =============
systemctl() {
	if [[ -f `which systemctl` ]]; then
		systemctl $1 $2
	else
		service $2 $1
	fi
}

Pre_Config() {
	if [[ pre_config_status -eq 0 ]]; then
		echo "-------------- 预配置 ---------------"
		[[ -f `which yum` ]] && echo -n "开始安装epel..." && $cmd -y install epel-release $notification_level && echo -e "\r$prompt_info epel安装完成"
		echo -n "开始更新..."
		$cmd update -y  $notification_level && echo -e "\r$prompt_info 更新完成" || [[ `echo -e "\r$prompt_error 更新失败" && exit 1` ]]
		echo -n "开始安装必要组件..."
		$cmd install -y wget curl unzip git gcc vim lrzsz screen ntp ntpdate cron net-tools telnet python-pip m2crypto $notification_level && echo -e "\r$prompt_info 必要组件安装完成 " || [[ `echo -e "\r$prompt_error 必要组件安装失败" && exit ` ]]
		echo -n "开始同步时间..."
		echo yes | cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime $notification_level
		ntpdate cn.pool.ntp.org  $notification_level
		hwclock -w $notification_level
		sed -i '/^.*ntpdate*/d' /etc/crontab
		echo '* * * * 1 ntpdate cn.pool.ntp.org > /dev/null 2>&1' >> /etc/crontab
		systemctl restart crond
		pre_config_status=1
		echo -e "\r$prompt_info 时间同步完成"
	fi
}

Db_Config_Reader() {
	echo "------------------- 数据库配置 -------------------"
    read -p "      数据库┬  地址（默认：127.0.0.1）：" Db_Host
	read -p "            ├─ 端口（默认：3306     ）：" Db_Port
	read -p "            ├─ 名称（默认：ssrpanel ）：" Db_Name
	read -p "            ├─ 用户（默认：ssrpanel ）：" Db_User
	read -p "            └─ 密码（默认：ssrpanel ）：" Db_Password
	echo
}

V2ray_Config_Reader() {
	echo "-------------------- v2ray配置 -------------------"
	read -p "           伪装域名（默认：localhost）：" V2ray_Domain
	read -p "               路径（默认：hello    ）：" V2ray_Path
	read -p "             额外ID（默认：16       ）：" V2ray_Alter_Id
	read -p "V2Ray端口，非80/443（默认：10086    ）：" V2ray_Port
	read -p "   ssrpanel同步端口（默认：10087    ）：" V2ray_Ssrpanel_Port
	read -p "            Node ID（默认：1        ）：" Node_Id
	echo
}

Httpd_Remove_judgment(){
	echo -ne "----------------------- ${red}警告${none} ---------------------\n检测到已安装httpd/apache，Caddy可能与httpd冲突，所以在安装caddy过程中会卸载httpd，请选择：\n------------------------------\n${green}y. ${none}卸载httpd并继续安装Caddy\n${green}n. ${none}取消安装Caddy并返回主菜单\n\n${green}q. ${none}退出\n------------------------------\n是否继续？[y/n/q]："
    read -n1 yn
    case $yn in
        y) echo -n "正在卸载httpd/apache2..."
		   systemctl stop httpd && yum remove httpd -y 1>/dev/null 2>&1 && echo -e "\r$prompt_warning httpd/apache2卸载完成";;
		q) exit 1;;
        *) Menu;;
    esac
    echo
}

Fi$rewaficationng(){lt_info 防火墙规则配置完成\n"
}

$Instficationy() {ln\n"
	Firewall_Setting

	systemctl restart caddy
}

#============ 菜单选项 ============


Install_V2ray) {
	Pr_Config
	V2ray_Config_Reader
	Db_Config_Reader
	Firewall_Setting
	echo "------------------ V2Ray安装 -------------------"
	echo -n "开始安装V2ray..."
	[[ `bash <(curl-L -s https:/install.direct/o.sh) $notification_level` ]] && echo -e "\r${prompt_info} V2ray安装完成"

	echo n "开始获取V2ray配置文件..."
	[[ `wget --no-check-cetificate -O config.json https://raw.githubusercontent.com/JadeVane/shell/master/resource/v2ray-config.json 2>/dev/null` ]] && echo -e "${prompt_info} 获取V2ray配置文件成功"
	echo -n "开始配置V2ray..."
	sed -i  -e "s/V2ray_Port/$V2ray_Port/g" \
			-e "s/V2ray_Alter_Id/$V2ray_Alter_Id/g" \
			-e "s/Vray_Path/$V2ray_Path/g" \
			-e "s/V2ray_Ssrpanel_Port/$V2ray_Ssrpanel_Port/g" \
			-e "s/Noded/$Node_Id/g" \
			-e "s/Db_Host/$Db_Host/g" \
			-e "s/Db_Port/$Db_Port/g" \
			-e "s/Db_Name$Db_Name/g" \
			-e "s/Db_User/$Db_User/g" \
			-e "s/Db_Password/$Db_Password/g" config.json
	[[ `mv -f onfig.json /etc/v2ray/` ]] && echo -e "\r${prompt_info} 配置文件写入完成"
	
	[[ `systemctl restart v2ray $notification_level && systemctl enable v2ray $notification_level` ]] && echo -e "${prompt_info} 已启动V2ray并设置开机自启\n" || [[ echo -e "${prompt_error} 启动v2ray失败，正在退出安装程序" && exit 1]]
}

Install_V2ray_Caddy() {
	V2ray_Config_Reader
	Db_Config_Reader
	Firewall_Setting
	Install_Caddy
	Install_V2ray
$}

IficationSR(){l
	echo -e "\r$prompt_warning 已启动SSR并设置开机自启\n"
}

Open_BBR(){
	cd
		wget -N --no-check-certificate "https://raw.githubusercontent.com/JadeVane/shell/master/others/bbr_tcp_mod.sh"
	bash bbr_tcp_mod.sh
}

#============ 主菜单 =============
picking() {
	read -s -n1 menu_picking
	case "$menu_picking" in
		1) clear
		   Install_V2ray;;
		2) clear
		   Install_V2ray_Caddy;;
		3) clear
		   Install_SSR;;
		4) clear
		   Open_BBR;;
		d) clear
		   description;;
		q) echo
		   exit 0;;
		*) echo -ne "\r   输入错误，请重新输入:"
		   picking;;
	esac
}

description() {
	echo -e "                         ${yellow}===== 使用事项 =====${none}"
	echo -e "1. BBR的安装目前仅在CentOS 7平台上进行测试，不保证在其他平台也能用"
	echo -e "2. V2ray安装使用最安全的ws+tls+web的形式，会附带一篇英语美文作为伪装网站"
	echo -e "3. 运行过程中显示信息的颜色含义：\n  ${green}绿色${none} - 正常\n  ${yellow}黄色${none} - 需要注意\n  ${red}红色${none} - 错误\n"
	echo -e "                         ${yellow}===== 关于脚本 =====${none}"
	echo -e "1. 推荐通过网络使用最新版的脚本："
	echo -e "  bash <(curl -L -s https://raw.githubusercontent.com/JadeVane/shell/master/shell/v2ray-ssr-deploy.sh)"
	echo -e "2. 使用脚本中如发现问题，可在以下站点反馈："
	echo -e "  https://github.com/JadeVane/shell/issues"
	echo -e "  https://www.wenjinyu.me/board\n"
	echo -e "                         ${yellow}======== End =======${none}"
	echo -e "                           ${green}c.${none} 更新脚本"
	echo -e "                           ${green}m.${none} 返回主菜单"
	echo -e "                           ${green}q.${none} 退出"
	echo -e "                           -------------"
	echo -ne "                           请选择操作："
	read -n1 des_picking
	case $des_picking in
		q) echo
		   exit 1;;
		c) bash <(curl -L -s https://raw.githubusercontent.com/JadeVane/shell/master/shell/v2ray-ssr-deploy.sh);;
		*) Menu;;
	esac
}

Menu(){"
	echo -e "   ${green}q.${none} 退出"
	echo -e "   ---------------------------------"
	echo -ne "   请选择:"
	picking
}

Menu