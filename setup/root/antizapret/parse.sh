#!/bin/bash
set -e

handle_error() {
	echo ""
	echo -e "\e[1;31mError occurred at line $1 while executing: $2\e[0m"
	echo ""
	exit 1
}
trap 'handle_error $LINENO "$BASH_COMMAND"' ERR

HERE="$(dirname "$(readlink -f "${0}")")"
cd "$HERE"

# Обрабатываем список заблокированных ресурсов
# Удаляем лишнее и преобразуем доменные имена содержащие международные символы в формат Punycode
awk -F ';' '{
	if ($2 ~ /\./ && $2 ~ /^[а-яА-Яa-zA-Z0-9\-_\.\*]+$/) {
		gsub(/^\*\./, "", $2);	# Удаление *. в начале
		gsub(/\.$/, "", $2);	# Удаление . в конце
		print $2				# Выводим только доменные имена
	}
}' temp/list.csv | CHARSET=UTF-8 idn --no-tld > temp/blocked-hosts.txt

# Удалим домены больше 4-ого уровня
sed -i -E 's/^.*\.(.*\..*\..*\..*)$/\1/' temp/blocked-hosts.txt

# Подготавливаем исходные файлы для обработки
( sed -E '/^#/d; /^[[:space:]]*$/d; s/^[[:space:]]+//; s/[[:space:]]+$//' config/exclude-hosts-{dist,custom}.txt && cat temp/nxdomain.txt ) | sort -u > temp/exclude-hosts.txt
( sed -E '/^#/d; /^[[:space:]]*$/d; s/^[[:space:]]+//; s/[[:space:]]+$//' config/include-hosts-{dist,custom}.txt && cat temp/blocked-hosts.txt) | sort -u > temp/include-hosts.txt

# Очищаем список доменов
awk -f config/exclude-regexp-dist.awk temp/include-hosts.txt > temp/cleared-blocked-hosts.txt

# Убираем домены из исключений
awk 'NR==FNR {exclude[$0]; next} !($0 in exclude)' temp/exclude-hosts.txt temp/cleared-blocked-hosts.txt > temp/blocked-hosts.txt

# Убираем домены у которых уже есть домены верхнего уровня
grep -vFf <(grep -E '^([^.]*\.){0,1}[^.]*$' temp/blocked-hosts.txt | sed 's/^/./') temp/blocked-hosts.txt > result/blocked-hosts.txt

# Generate knot-resolver aliases
echo 'blocked_hosts = {' > result/blocked-hosts.conf
while read -r line
do
	line="$line."
	echo "${line@Q}," >> result/blocked-hosts.conf
done < result/blocked-hosts.txt
echo '}' >> result/blocked-hosts.conf

# Print results
echo "Blocked domains: $(wc -l result/blocked-hosts.txt)"

exit 0