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
		[[ -f `which yum` ]] && echo -n "开始安装epel..." && $cmd -y install epel-release 2>&1 1>/dev/null && echo -e "\r$prompt_info epel安装完成"
		echo -n "开始更新..."
		$cmd update -y  2>&1 1>/dev/null && echo -e "\r$prompt_info 更新完成" || echo -e "\r$prompt_error 更新失败" && exit 1
		echo -n "开始安装必要组件..."
		$cmd install -y wget curl unzip git gcc vim lrzsz screen ntp ntpdate cron net-tools telnet python-pip m2crypto 2>&1 1>/dev/null && echo -e "\r$prompt_info 必要组件安装完成 " || echo -e "\r$prompt_error 必要组件安装失败" && exit 1
		echo -n "开始同步时间..."
		echo yes | cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 2>&1 1>/dev/null
		ntpdate cn.pool.ntp.org  2>&1 1>/dev/null
		hwclock -w 2>&1 1>/dev/null
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
        *) Menu;;
    esac
    echo
}

Firewall_Setting(){
	echo "------------------- 防火墙配置 -------------------"
	if command -v firewall-cmd 2>&1 1>/dev/null; then
		echo -e "${prompt_info} 已安装firewalld，开始进行防火墙配置"
		systemctl status firewalld 2>&1 1>/dev/null
		if [ $? -eq 0 ]; then
			firewall-cmd --permanent --zone=public --remove-port=443/tcp 2>&1 1>/dev/null
			firewall-cmd --permanent --zone=public --remove-port=80/tcp 2>&1 1>/dev/null
			firewall-cmd --permanent --zone=public --add-port=443/tcp 2>&1 1>/dev/null
			firewall-cmd --permanent --zone=public --add-port=80/tcp 2>&1 1>/dev/null
			echo -e "$prompt_info 已放行端口：80, 443"
			if [[ $V2ray_Port ]]; then
				firewall-cmd --permanent --zone=public --remove-port=${V2ray_Port}/tcp 2>&1 1>/dev/null
				firewall-cmd --permanent --zone=public --remove-port=${V2ray_Port}/udp 2>&1 1>/dev/null
				firewall-cmd --permanent --zone=public --add-port=${V2ray_Port}/tcp 2>&1 1>/dev/null
				firewall-cmd --permanent --zone=public --add-port=${V2ray_Port}/udp 2>&1 1>/dev/null
				firewall-cmd --reload 2>&1 1>/dev/null
				echo -e "$prompt_info 已放行V2ray端口：${V2ray_Port}"
			fi
			if [[ $Ss_Single_Port ]]; then
				firewall-cmd --permanent --zone=public --remove-port=${Ss_Single_Port}/tcp 2>&1 1>/dev/null
				firewall-cmd --permanent --zone=public --remove-port=${Ss_Single_Port}/udp 2>&1 1>/dev/null
				firewall-cmd --permanent --zone=public --add-port=${Ss_Single_Port}/tcp 2>&1 1>/dev/null
				firewall-cmd --permanent --zone=public --add-port=${Ss_Single_Port}/udp 2>&1 1>/dev/null
				firewall-cmd --reload 2>&1 1>/dev/null
				echo -e "$prompt_info 已放行SS端口：${Ss_Single_Port}"
			fi
		else
			echo -e "$prompt_warning firewalld似乎未安装，或已安装但未启动，如有必要，请手动设置防火墙规则"
		fi
		echo -e "$prompt_info firewalld防火墙规则配置完成"
	elif command -v iptables 2>&1 1>/dev/null; then
		echo -e "${prompt_info} 开始进行iptables防火墙配置"
		/etc/init.d/iptables status 2>&1 1>/dev/null
		if [ $? -eq 0 ]; then
			iptables -D INPUT -p tcp --dport 443 -j ACCEPT
			iptables -D INPUT -p tcp --dport 80 -j ACCEPT
			iptables -A INPUT -p tcp --dport 443 -j ACCEPT
			iptables -A INPUT -p tcp --dport 80 -j ACCEPT
			ip6tables -D INPUT -p tcp --dport 443 -j ACCEPT
			ip6tables -D INPUT -p tcp --dport 80 -j ACCEPT
			ip6tables -A INPUT -p tcp --dport 443 -j ACCEPT
			ip6tables -A INPUT -p tcp --dport 80 -j ACCEPT
			[[ $? -ne 0 ]] && echo -e "$prompt_info 已放行端口：80, 443"
			iptables -L -n | grep -i ${V2ray_Port} 2>&1 1>/dev/null
			if [ $? -ne 0 ]; then
				iptables -D INPUT -p tcp --dport ${V2ray_Port} -j ACCEPT
				iptables -A INPUT -p tcp --dport ${V2ray_Port} -j ACCEPT
				iptables -D INPUT -p udp --dport ${V2ray_Port} -j ACCEPT
				iptables -A INPUT -p udp --dport ${V2ray_Port} -j ACCEPT
				ip6tables -D INPUT -p tcp --dport ${V2ray_Port} -j ACCEPT
				ip6tables -A INPUT -p tcp --dport ${V2ray_Port} -j ACCEPT
				ip6tables -D INPUT -p udp --dport ${V2ray_Port} -j ACCEPT
				ip6tables -A INPUT -p udp --dport ${V2ray_Port} -j ACCEPT
				/etc/init.d/iptables save
				/etc/init.d/iptables restart
				/etc/init.d/ip6tables save
				/etc/init.d/ip6tables restart
			else
				echo -e "$prompt_info 已放行V2ray端口：${V2ray_Port}"
			fi
			iptables -L -n | grep -i ${Ss_Single_Port} > /dev/null 2>&1
			if [ $? -ne 0 ]; then
				iptables -D INPUT -p tcp --dport ${Ss_Single_Port} -j ACCEPT
				iptables -A INPUT -p tcp --dport ${Ss_Single_Port} -j ACCEPT
				iptables -D INPUT -p udp --dport ${Ss_Single_Port} -j ACCEPT
				iptables -A INPUT -p udp --dport ${Ss_Single_Port} -j ACCEPT
				ip6tables -D INPUT -p tcp --dport ${Ss_Single_Port} -j ACCEPT
				ip6tables -A INPUT -p tcp --dport ${Ss_Single_Port} -j ACCEPT
				ip6tables -D INPUT -p udp --dport ${Ss_Single_Port} -j ACCEPT
				ip6tables -A INPUT -p udp --dport ${Ss_Single_Port} -j ACCEPT
				/etc/init.d/iptables save
				/etc/init.d/iptables restart
				/etc/init.d/ip6tables save
				/etc/init.d/ip6tables restart
			else
				echo -e "$prompt_info 已放行SS端口：${Ss_Single_Port}"
			fi
		else
			echo -e "$prompt_warning iptables似乎未安装，或已安装但未启动，如有必要，请手动设置防火墙规则"
		fi
		echo -e "$prompt_info iptables防火墙规则配置完成"
	fi
	echo -e "$prompt_info 防火墙规则配置完成\n"
}

Install_Caddy() {

	echo "-------------------- 安装Caddy -------------------"
	if [[ $cmd == "yum" ]]; then
		[[ $(pgrep "httpd") || $(pgrep "apache2") ]] && Httpd_Remove_judgment
	fi

	local caddy_dir="/tmp/caddy_install/"
	local caddy_installer="/tmp/caddy_install/caddy.tar.gz"

	echo -ne "开始匹配安装包"
	if [[ $sys_bit == "i386" || $sys_bit == "i686" ]]; then
		local caddy_download_link="https://caddyserver.com/download/linux/386?license=personal"
		echo -e "\r${prompt_info} 匹配安装包成功"
	elif [[ $sys_bit == "x86_64" ]]; then
		local caddy_download_link="https://caddyserver.com/download/linux/amd64?license=personal"
		echo -e "\r${prompt_info} 匹配安装包成功"
	else
		echo -e "\r$prompt_error 匹配Caddy失败！不是i386或x86_64系统" && exit 1
	fi
	echo -n "正在下载Caddy安装包..."
	wget --no-check-certificate -O "$caddy_installer" $caddy_download_link 2>/dev/null
	if [[ $? -eq 0 ]]; then
		echo -e "\r$prompt_info Caddy安装包下载完成"
	else
		echo -e "\r$prompt_error Caddy安装包下载失败" && exit 1
	fi

	echo -n "正在解压Caddy安装包..."
	mkdir -p $caddy_dir
	tar zxf $caddy_installer -C $caddy_dir 2>&1 1>/dev/null
	if [ $? -eq 0 ]; then
		echo -e "\r$prompt_info Caddy安装包解压完成"
	else
		echo -e "\r$prompt_error Caddy安装包解压失败"
	fi

	echo -ne "正在安装Caddy...      \b\b\b\b\b\b"
	cp -f ${caddy_dir}caddy /usr/local/bin/

	if [[ ! -f /usr/local/bin/caddy ]]; then
		echo -e "\r$prompt_error 安装Caddy出错！" && exit 1
	fi

	setcap CAP_NET_BIND_SERVICE=+eip $(which caddy)

	if [[ -f `which systemctl` ]]; then
		cp -f ${caddy_dir}init/linux-systemd/caddy.service /lib/systemd/system/
		[[ `systemctl enable caddy 2>&1 1>/dev/null` ]] && echo -e "\r${prompt_info} Caddy已设置开机自启"
	else
		cp -f ${caddy_dir}init/linux-sysvinit/caddy /etc/init.d/caddy
		chmod +x /etc/init.d/caddy
		[[ `update-rc.d -f caddy defaults 2>&1 1>/dev/null` ]] && echo -e "\r${prompt_info} Caddy已设置开机自启"
	fi

	mkdir -p /etc/ssl/caddy

	if [ -z "$(grep www-data /etc/passwd)" ]; then
		useradd -M -s /usr/sbin/nologin www-data 2>&1 1>/dev/null
	fi
	chown -R www-data.www-data /etc/ssl/caddy
	rm -rf $caddy_dir
	echo -e "\r$prompt_info Caddy安装完成"

	echo -n "正在创建一个简单的伪装网站..."
	wget --no-check-certificate -O index.html https://raw.githubusercontent.com/JadeVane/shell/master/web/index.html  2>/dev/null
	mkdir -p /var/www/v2ray/
	mv index.html /var/www/v2ray/
	# 修改配置
	mkdir -p /etc/caddy/
	wget --no-check-certificate -O Caddyfile https://raw.githubusercontent.com/JadeVane/shell/master/resource/Caddyfile 2>/dev/null
	local User_Name=$(((RANDOM << 22)))
	sed -i  -e "s/User_Name/$User_Name/" \
			-e "s/V2ray_Domain/$V2ray_Domain/" \
			-e "s/V2ray_Path/$V2ray_Path/" \
			-e "s/V2ray_Port/$V2ray_Port/" Caddyfile
	mv -f Caddyfile /etc/caddy/
	echo -e "\r$prompt_info 创建伪装网站完成，伪装网址：$V2ray_Domain\n"
	Firewall_Setting

	systemctl restart caddy
}

#============ 菜单选项 ============


Install_V2ray() {
	Pre_Config
	V2ray_Config_Reader
	Db_Config_Reader
	Firewall_Setting
	echo "-------------------- V2Ray安装 -------------------"
	echo -n "开始安装V2ray..."
	[[ `bash <(curl -L -s https://install.direct/go.sh) 2>&1 1>/dev/null` ]] && echo -e "\r${prompt_info} V2ray安装完成"

	echo -n "开始配置V2ray..."
	wget --no-check-certificate -O config.json https://raw.githubusercontent.com/JadeVane/shell/master/resource/v2ray-config.json 2>&1 1>/dev/null
	sed -i  -e "s/V2ray_Port/$V2ray_Port/g" \
			-e "s/V2ray_Alter_Id/$V2ray_Alter_Id/g" \
			-e "s/V2ray_Path/$V2ray_Path/g" \
			-e "s/V2ray_Ssrpanel_Port/$V2ray_Ssrpanel_Port/g" \
			-e "s/Node_Id/$Node_Id/g" \
			-e "s/Db_Host/$Db_Host/g" \
			-e "s/Db_Port/$Db_Port/g" \
			-e "s/Db_Name/$Db_Name/g" \
			-e "s/Db_User/$Db_User/g" \
			-e "s/Db_Password/$Db_Password/g" config.json
	[[ `mv -f config.json /etc/v2ray/` ]] && echo -e "\r${prompt_info} 配置文件写入完成"
	systemctl restart v2ray
	systemctl enable v2ray 2>&1 1>/dev/null
	echo "${prompt_info} 已启动V2ray并设置开机自启\n"
}

Install_V2ray_Caddy() {
	V2ray_Config_Reader
	Db_Config_Reader
	Firewall_Setting
	Install_Caddy
	Install_V2ray
}

Install_SSR(){
	Pre_Config
	display_info="--------------------- SSR配置 --------------------\n"
	echo $display_info
	echo -ne "1. none（默认）\n2. rc4-md5\n3. aes-256-cfb\n4. chacha20\n\n请选择加密方式："
	read -n1 Ss_Method
	case $Ss_Method in
		1) Ss_Method="none";;
		2) Ss_Method="rc4-md5";;
		3) Ss_Method="aes-256-cfb";;
		4) Ss_Method="chacha20";;
		*) Ss_Method=$Ss_Method;;
	esac
	clear
	display_info="$display_info     已选择加密方式（默认：none     ）：$Ss_Method\n"
	echo -ne "$display_info--------------------\n1. origin（默认）\n2. auth_sha1_v4\n3. auth_aes128_md5\n4. auth_chain_a\n\n请选择传输协议："
	read -n1 Ss_Protocol
	case $Ss_Protocol in
		1) Ss_Protocol="origin";;
		2) Ss_Protocol="auth_sha1_v4";;
		3) Ss_Protocol="auth_aes128_md5";;
		4) Ss_Protocol="auth_chain_a";;
		*) Ss_Protocol=$Ss_Protocol;;
	esac
	clear
	display_info="$display_info     已选择传输协议（默认：origin   ）：$Ss_Protocol\n"
	echo -ne "$display_info--------------------\n1. plain（默认）\n2. http_simple\n3. http_post\n4. tls1.2_ticket_auth\n\n请选择混淆方式："
	read -n1 Ss_Obfs
	case $Ss_Obfs in
		1) Ss_Obfs="plain";;
		2) Ss_Obfs="http_simple";;
		3) Ss_Obfs="http_post";;
		4) Ss_Obfs="tls1.2_ticket_auth";;
		*) Ss_Obfs=$Ss_Obfs;;
	esac
	clear
	display_info="$display_info     已选择混淆方式（默认：plain    ）：$Ss_Obfs"
	echo -e "$display_info"
	read -p "            Node ID（默认：1        ）：" Node_Id
	read -p "       流量计算比例（默认：1        ）：" V2ray_Transfer_Ratio
    read -p "     是否强制单端口（默认：否  ）[y/n]：" Ss_Single_Port_Enable
    case $Ss_Single_Port_Enable in
    	y) Ss_Single_Port_Enable="true";;
		*) Ss_Single_Port_Enable="false";;
	esac
	read -p "             端口号（默认：8080     ）：" Ss_Single_Port
	read -p "           认证密码（默认：hello    ）：" Ss_Password
	read -p "     限制使用设备数（默认：不限制   ）：" Ss_Online_Limit
	[[ -n $Ss_Online_Limit ]] && Ss_Online_Limit="${Ss_Online_Limit}#"
	read -p "     用户限速值(K)：(默认：不限制   ）：" Ss_Speed_Limit
	echo
	Db_Config_Reader
	Firewall_Setting
	echo "--------------------- SSR安装 --------------------"
	echo -ne "开始下载SSR..."
	cd /usr/
	rm -rf /usr/shadowsocksr
	[[ `git clone -b master https://github.com/JadeVane/shadowsocksr.git 2>&1 1>/dev/null` ]] && echo -e "\r$prompt_warning 下载SSR成功   " || echo -e "\r$prompt_error 下载SSR失败   " && exit 1

	cd shadowsocksr
	echo -n "开始安装依赖..."
	bash setup_cymysql.sh 2>&1 1>/dev/null
	echo -ne "\r初始化配置...      "
	bash initcfg.sh  2>&1 1>/dev/null
	echo -e '\r$prompt_info SSR安装完成'

	echo -n "正在写入配置文件..."
	sed -i  -e "s/Db_Host/$Db_Host/g" \
			-e "s/Db_Port/$Db_Port/g" \
			-e "s/Db_Name/$Db_Name/g" \
			-e "s/Db_User/$Db_User/g" \
			-e "s/Db_Password/$Db_Password/g" \
			-e "s/Node_Id/$Node_Id/g" \
			-e "s/V2ray_Transfer_Ratio/$V2ray_Transfer_Ratio/g" usermysql.json

	sed -i  -e "s/Ss_Single_Port_Enable/$Ss_Single_Port_Enable/g" \
			-e "s/Ss_Single_Port/$Ss_Single_Port/g" \
			-e "s/Ss_Password/$Ss_Password/g" \
			-e "s/Ss_Method/$Ss_Method/g" \
			-e "s/Ss_Protocol/$Ss_Protocol/g" \
			-e "s/Ss_Obfs/$Ss_Obfs/g" \
			-e "s/Ss_Online_Limit/$Ss_Online_Limit/g" \
			-e "s/Ss_Speed_Limit/$Ss_Speed_Limit/g" user-config.json

	echo -ne "\r正在启动SSR...        "
	wget -N --no-check-certificate -P /etc/systemd/system/shadowsocksr.service https://raw.githubusercontent.com/JadeVane/shell/master/resource/shadowsocksr.service  2>&1 1>/dev/null
	systemctl start shadowsocksr
	systemctl enable shadowsocksr 2>&1 1>/dev/null
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
	echo -e "                           ${green}m.${none} 返回主菜单"
	echo -e "                           ${green}q.${none} 退出"
	echo -e "                           -------------"
	echo -ne "                         请选择操作："
	read -n1 des_picking
	case $des_picking in
		q) echo
		   exit 1;;
		*) Menu;;
	esac
}

Menu(){
	clear
	echo -e "==========================================="
	echo -e "       ${button} SSRPanel V2ray节点一键部署脚本 ${none} v1.0\n"
	echo -e "     ${green}系统要求：CentOS 7+ or Ubuntu 14+"
	echo -e "     更新地址：https://www.wenjinyu.me${none}"
	echo -e "==========================================="
	echo -e "\n   ------------- 主菜单 ------------"
	echo -e "   ${green}1.${none} 安装 V2Ray（作为节点）"
	echo -e "   ${green}2.${none} 安装 V2Ray+Caddy"
	echo -e "   ${green}3.${none} 安装 SSR（作为节点）"
	echo -e "   ${green}4.${none} 启用 BBR（仅CentOS）\n"
	echo -e "   ${green}d.${none} 说明（${yellow}首次使用先阅读${none}）\n"
	echo -e "   ${green}q.${none} 退出"
	echo -e "   ---------------------------------"
	echo -ne "   请选择:"
	picking
}

Menu