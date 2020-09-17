#!/bin/sh
 
#检查传入参数
[ -z "$username" ] && write_log 14 "配置错误![用户名]不能为空"
[ -z "$password" ] && write_log 14 "配置错误![密码]不能为空"
 
#检查外部工具curl,sed
command -v curl >/dev/null 2>&1 || write_log 13 "需要curl支持,请先安装"
command -v sed >/dev/null 2>&1 || write_log 13 "需要 sed 支持，请先安装"
 
# 变量声明
local __HOST __DOMAIN __TYPE __RECIP __RECID DATFILE
 
# 从 $domain 分离主机和域名
[ "${domain:0:2}" == "@." ] && domain="${domain/./}" # 主域名处理
[ "$domain" == "${domain/@/}" ] && domain="${domain/./@}" # 未找到分隔符，兼容常用域名格式
__HOST="${domain%%@*}"
__DOMAIN="${domain#*@}"
[ -z "$__HOST" -o "$__HOST" == "$__DOMAIN" ] && __HOST="@"
 
# 设置记录类型
[ $use_ipv6 -eq 0 ] && __TYPE="A" || __TYPE="AAAA"
 
#添加解析记录
add_domain() {
DATFILE=`curl -s -d "login_token=$username,$password&format=json&domain=$__DOMAIN&sub_domain=$__HOST&record_type=$__TYPE&record_line_id=0&value=${__IP}&ttl=600" "https://dnsapi.cn/Record.Create"`
value=`jsonfilter -s "$DATFILE" -e "@.status.code"`
if [ $value == 1 ];then
	write_log 7 "添加新解析记录IP:[$__HOST],[$__TYPE],[${__IP}]成功!"
else
	write_log 14 "添加解析记录IP:[$__HOST],[$__TYPE],[${__IP}]失败! 返回code:$value"
fi
}
 
#修改解析记录
update_domain() {
DATFILE=`curl -s -d "login_token=$username,$password&format=json&domain=$__DOMAIN&record_id=$__RECID&value=${__IP}&record_type=$__TYPE&record_line_id=0&sub_domain=$__HOST&ttl=600" "https://dnsapi.cn/Record.Modify"`
value=`jsonfilter -s "$DATFILE" -e "@.status.code"`
if [ $value == 1 ];then
	write_log 7 "修改解析记录host:[$__HOST],type:[$__TYPE],ip:[${__IP}]成功!"
else
	write_log 14 "修改解析记录host:[$__HOST],type:[$__TYPE],ip:[${__IP}]失败! 返回code:$value"
fi
}
 
#获取域名解析记录
describe_domain() {
	DATFILE=`curl -s -d "login_token=$username,$password&format=json&domain=$__DOMAIN" "https://dnsapi.cn/Record.List"`
	value=`jsonfilter -s "$DATFILE" -e "@.records[@.name='$__HOST'].name"`
	if [ "$value" == "" ]; then
		write_log 7 "解析记录:[$__HOST]不存在,类型: HOST"
		ret=1
	else
		value=`jsonfilter -s "$DATFILE" -e "@.records[@.name='$__HOST'].type"`
		if [ "$value" != "$__TYPE" ]; then
				write_log 7 "当前解析类型:[$__TYPE], 获得不匹配类型: TYPE"
				ret=2; continue
		else
			__RECID=`jsonfilter -s "$DATFILE" -e "@.records[@.name='$__HOST'].id"`
			write_log 7 "获得解析记录ID:[$__RECID], 类型: ID"
			__RECIP=`jsonfilter -s "$DATFILE" -e "@.records[@.name='$__HOST'].value"`
			if [ "$__RECIP" != "${__IP}" ]; then
				write_log 7 "地址需要修改,本地地址:[${__IP}]"
				ret=2
			fi
		fi
	fi
	return $ret
}
describe_domain
ret=$?
if [ $ret == 1 ];then
	sleep 3 && add_domain
elif [ $ret == 2 ];then
	sleep 3 && update_domain
else
	write_log 7 "本地IP：“${__IP}” 解析记录IP：“$__RECIP”地址不需要修改"
fi

return 0
