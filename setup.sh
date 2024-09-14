#!/bin/bash
#
# Скрипт для автоматического развертывания AntiZapret VPN + обычный VPN
# Версия от 14.09.2024
#
# https://github.com/GubernievS/AntiZapret-VPN
#
# Протестировано на Ubuntu 22.04/24.04 и Debian 11*/12 - Процессор: 1 core Память: 1 Gb Хранилище: 10 Gb
# * Debian 11 требует установки обновления dnslib
#
# Установка:
# 1. Устанавливать на Ubuntu 22.04/24.04 или Debian 11*/12 (рекомендуется Ubuntu 24.04)
# 2. В терминале под root выполнить:
# apt update && apt install -y git && git clone https://github.com/GubernievS/AntiZapret-VPN.git tmp && cd tmp && chmod +x setup.sh && ./setup.sh
# 3. Дождаться перезагрузки сервера и скопировать файлы *.ovpn с сервера из папки /root

set -e

#
# Обновляем систему
apt update
DEBIAN_FRONTEND=noninteractive apt full-upgrade -y -o Dpkg::Options::="--force-confdef"
apt autoremove -y

#
# Ставим необходимые пакеты
DEBIAN_FRONTEND=noninteractive apt install -y git openvpn iptables easy-rsa ferm gawk knot-resolver idn sipcalc curl gpg

#
# Если не был установлен dnslib то ставим python3-dnslib
if ! python3 -c "import dnslib" 2>/dev/null; then
	DEBIAN_FRONTEND=noninteractive apt install -y python3-dnslib
fi

#
# Сохраняем include-hosts-custom.txt
mv /root/antizapret/config/include-hosts-custom.txt /root || true

#
# Обновляем antizapret до последней версии из репозитория
rm -rf /root/antizapret
git clone https://bitbucket.org/anticensority/antizapret-pac-generator-light.git /root/antizapret

#
# Восстанавливаем include-hosts-custom.txt
mv /root/include-hosts-custom.txt /root/antizapret/config || true

#
# Удаляем исключения из исключений антизапрета
sed -i "/\b\(youtube\|youtu\|ytimg\|ggpht\|googleusercontent\|cloudfront\|ftcdn\)\b/d" /root/antizapret/config/exclude-hosts-dist.txt
sed -i "/\b\(googleusercontent\|cloudfront\|deviantart\)\b/d" /root/antizapret/config/exclude-regexp-dist.awk

#
# Исправляем шаблон для корректной работы gawk начиная с версии 5
sed -i "s/\\\_/_/" /root/antizapret/parse.sh

#
# Копируем нужные файлы и папки, удаляем не нужные
find /root/antizapret -name '*.gitkeep' -delete
rm -rf /root/antizapret/.git
find $PWD -name '*.gitkeep' -delete
cp -r $PWD/setup/* / 
rm -rf $PWD

#
# Выставляем разрешения на запуск скриптов
find /root -name "*.sh" -execdir chmod u+x {} +
chmod +x /root/dnsmap/proxy.py

#
# Создаем пользователя 'client', его ключи 'antizapret-client', ключи сервера 'antizapret-server' и создаем *.ovpn файлы подключений в /root
/root/add-client.sh client

#
# Добавляем AdGuard DNS для блокировки рекламы, отслеживающих модулей и фишинга
echo "
policy.add(policy.all(policy.FORWARD({'94.140.14.14', '94.140.15.15'})))" >> /etc/knot-resolver/kresd.conf

#
# Запустим все необходимые службы при загрузке
systemctl enable kresd@1
systemctl enable antizapret-update.service
systemctl enable antizapret-update.timer
systemctl enable dnsmap
systemctl enable openvpn-server@antizapret-udp
systemctl enable openvpn-server@antizapret-tcp
systemctl enable openvpn-server@vpn-udp
systemctl enable openvpn-server@vpn-tcp

echo ""
echo "AntiZapret-VPN successful installation! Rebooting..."

#
# Перезагружаем
reboot