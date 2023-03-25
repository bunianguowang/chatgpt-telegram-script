#!/bin/bash
red='\033[0;31m'
bblue='\033[0;34m'
yellow='\033[0;33m'
green='\033[0;32m'
plain='\033[0m'
red(){ echo -e "\033[31m\033[01m$1\033[0m";}
green(){ echo -e "\033[32m\033[01m$1\033[0m";}
yellow(){ echo -e "\033[33m\033[01m$1\033[0m";}
blue(){ echo -e "\033[36m\033[01m$1\033[0m";}
white(){ echo -e "\033[37m\033[01m$1\033[0m";}
bblue(){ echo -e "\033[34m\033[01m$1\033[0m";}
rred(){ echo -e "\033[35m\033[01m$1\033[0m";}
readtp(){ read -t5 -n26 -p "$(yellow "$1")" $2;}
readp(){ read -p "$(yellow "$1")" $2;}
[[ $EUID -ne 0 ]] && yellow "请以root模式运行脚本" && exit
if [[ -f /etc/redhat-release ]]; then
release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /etc/issue | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
elif cat /proc/version | grep -q -E -i "debian"; then
release="Debian"
elif cat /proc/version | grep -q -E -i "ubuntu"; then
release="Ubuntu"
elif cat /proc/version | grep -q -E -i "centos|red hat|redhat"; then
release="Centos"
else 
red "不支持你当前系统，请选择使用Ubuntu,Debian,Centos系统。" && exit
fi

start(){
systemctl stop firewalld.service >/dev/null 2>&1
systemctl disable firewalld.service >/dev/null 2>&1
setenforce 0 >/dev/null 2>&1
ufw disable >/dev/null 2>&1
iptables -P INPUT ACCEPT >/dev/null 2>&1
iptables -P FORWARD ACCEPT >/dev/null 2>&1
iptables -P OUTPUT ACCEPT >/dev/null 2>&1
iptables -t mangle -F >/dev/null 2>&1
iptables -F >/dev/null 2>&1
iptables -X >/dev/null 2>&1
netfilter-persistent save >/dev/null 2>&1
v4=$(curl -s4m6 ip.sb -k)
if [ -z $v4 ]; then
echo -e nameserver 2a01:4f8:c2c:123f::1 > /etc/resolv.conf
fi
}

inschat(){
if [[ -f '/root/TGchatgpt.py' ]]; then
red "已安装Chatgpt，请卸载后再重装" && exit
fi
systemctl stop Chatgpt.service
[[ $(type -P yum) ]] && yumapt='yum -y' || yumapt='apt -y'
$yumapt update
[[ ! $(type -P python3) ]] && (yellow "检测到python3未安装，升级安装中" && $yumapt update;$yumapt install python3)
if [[ $release = Centos ]]; then
yum install epel-release -y
[[ ! $(type -P python3-devel) ]] && ($yumapt update;$yumapt install python3-devel python3 -y)
else
[[ ! $(type -P python3-pip) ]] && ($yumapt update;$yumapt install python3-pip -y)
fi
py3=`python3 -V  | awk '{print $2}' | tr -d '.'`
if [[ $py3 -le 370 ]]; then
yellow "升级python3到3.7.3，升级时间比较长，请稍等……" && sleep 3
wget -N https://www.python.org/ftp/python/3.7.3/Python-3.7.3.tgz
tar -zxf Python-3.7.3.tgz
$yumapt install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc libffi-devel make -y
cd Python-3.7.3
./configure --prefix=/usr/local/python3.7
make && make install
#co=$(echo $? 2>&1)
#if [[ $co = 0 ]]; then
#green "升级python3成功"
ln -sf /usr/local/python3.7/bin/python3.7 /usr/bin/python3
#else
#red "升级python3失败" && exit
#fi
fi
pip3 install -U pip
python3 -m pip install openai aiogram 
cat > /root/TGchatgpt.py << EOF
import os
import signal
import time
import openai
import telegram
from telegram.ext import Updater, CommandHandler, MessageHandler, Filters
from dotenv import load_dotenv

load_dotenv()


bot_token = tgtoken

api_key = apikey


bot = telegram.Bot(token=bot_token)


updater = Updater(token=bot_token, use_context=True)


openai.api_key = api_key


def start(update, context):
    context.bot.send_message(chat_id=update.effective_chat.id, text="Hello, I'm ChatGPT! How can I help you?")


def echo(update, context):

    user_message = update.message.text


    completion = openai.ChatCompletion.create(
        model="gpt-3.5-turbo", 
        messages=[{"role": "user", "content": user_message}],
        max_tokens=1024,
        n=1,
        stop=None,
        temperature=0.5,
        frequency_penalty=0.5,
        presence_penalty=0.0
    )


    chatgpt_response = completion.choices[0]['message']


    context.bot.send_message(chat_id=update.effective_chat.id, text=chatgpt_response['content'])


updater.dispatcher.add_handler(CommandHandler('start', start))
updater.dispatcher.add_handler(MessageHandler(Filters.text & ~Filters.command, echo))

updater.start_polling()


while True:
    time.sleep(1)  
EOF

readp "输入Telegram的token：" token
sed -i "10 s/tgtoken/'$token'/" /root/TGchatgpt.py
readp "输入Openai的apikey：" key
sed -i "11 s/apikey/'$key'/" /root/TGchatgpt.py

cat << EOF >/lib/systemd/system/Chatgpt.service
[Unit]
Description=ygkkk-Chatgpt Service
After=network.target
[Service]
Restart=on-failure
User=root
ExecStart=/usr/bin/python3 /root/TGchatgpt.py
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable Chatgpt.service
systemctl start Chatgpt.service
systemctl stop Chatgpt.service
systemctl restart Chatgpt.service
green "Chatgpt Telegram机器人安装完毕"
}

chatlog(){
cat /root/bot.log | tail -n 10
}

stclre(){
if [[ ! -f '/root/TGchatgpt.py' ]]; then
red "未正常安装Chatgpt" && exit
fi
green "Chatgpt服务执行以下操作"
readp "1. 重启\n2. 关闭\n3. 启动\n请选择：" action
if [[ $action == "1" ]]; then
systemctl stop Chatgpt.service
systemctl restart Chatgpt.service
green "Chatgpt服务重启\n"
elif [[ $action == "2" ]]; then
systemctl stop Chatgpt.service
systemctl disable Chatgpt.service
green "Chatgpt服务关闭\n"
elif [[ $action == "3" ]]; then
systemctl enable Chatgpt.service
systemctl start Chatgpt.service
systemctl stop Chatgpt.service
systemctl restart Chatgpt.service
green "Chatgpt服务开启\n"
else
red "输入错误,请重新选择" && stclre
fi
}

changechat(){
if [[ ! -f '/root/TGchatgpt.py' ]]; then
red "未正常安装Chatgpt" && exit
fi
green "Chatgpt参数变更选择如下:"
readp "1. 更换Telegram的token\n2. 更换Openai的apikey\n请选择：" choose
if [ $choose == "1" ];then
tgtoken=`cat /root/TGchatgpt.py | sed -n 10p | awk '{print $3}'`
readp "输入Telegram的token：" token
sed -i "10 s/$tgtoken/'$token'/" /root/TGchatgpt.py
systemctl stop Chatgpt.service
systemctl restart Chatgpt.service
elif [ $choose == "2" ];then
apikey=`cat /root/TGchatgpt.py | sed -n 11p | awk '{print $3}'`
readp "输入Openai的apikey：" key
sed -i "11 s/$apikey/'$key'/" /root/TGchatgpt.py
systemctl stop Chatgpt.service
systemctl restart Chatgpt.service
else 
red "请重新选择" && changechat
fi
}

unins(){
systemctl stop Chatgpt.service >/dev/null 2>&1
systemctl disable Chatgpt.service >/dev/null 2>&1
rm -f /lib/systemd/system/Chatgpt.service /root/TGchatgpt.py /root/bot.log
green "Chatgpt-TG卸载完成！"
}

start_menu(){
clear
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"           
echo -e "${bblue} ░██     ░██      ░██ ██ ██         ░█${plain}█   ░██     ░██   ░██     ░█${red}█   ░██${plain}  "
echo -e "${bblue}  ░██   ░██      ░██    ░░██${plain}        ░██  ░██      ░██  ░██${red}      ░██  ░██${plain}   "
echo -e "${bblue}   ░██ ░██      ░██ ${plain}                ░██ ██        ░██ █${red}█        ░██ ██  ${plain}   "
echo -e "${bblue}     ░██        ░${plain}██    ░██ ██       ░██ ██        ░█${red}█ ██        ░██ ██  ${plain}  "
echo -e "${bblue}     ░██ ${plain}        ░██    ░░██        ░██ ░██       ░${red}██ ░██       ░██ ░██ ${plain}  "
echo -e "${bblue}     ░█${plain}█          ░██ ██ ██         ░██  ░░${red}██     ░██  ░░██     ░██  ░░██ ${plain}  "
green "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 
white "甬哥Github项目  ：github.com/yonggekkk"
white "甬哥blogger博客 ：ygkkk.blogspot.com"
white "甬哥YouTube频道 ：www.youtube.com/@ygkkk"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
green " 1. 安装Chatgpt-TG聊天" 
green " 2. 卸载Chatgpt-TG聊天"
green " 3. 关闭、开启、重启Chatgpt"    
green " 4. 更换TG的token 或 Openai的apikey"
green " 5. 查看Chatgpt-TG服务日志"
green " 0. 退出脚本"
red "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo
readp "请输入数字:" Input
case "$Input" in     
 1 ) inschat;;
 2 ) unins;;
 3 ) stclre;;
 4 ) changechat;;
 5 ) chatlog;;
 * ) exit 
esac
}
if [ $# == 0 ]; then
start
start_menu
fi
