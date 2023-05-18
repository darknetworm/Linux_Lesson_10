#!/bin/bash

# определяем файл, необходимый для запуска единственного экземпляра скрипта
lockfile=/tmp/report.txt

# определяем текущую дату в нужном форматe
date_now="$(date -R)"
date_now="${date_now:5:21}"
date_now="$(echo $date_now | sed 's+ +/+;s+ +/+;s+ +:+')"

# определяем дату предыдущего срабатывания скрипта (на час ранее)
date_last_start="$(date -R --date '-60 min')"
date_last_start="${date_last_start:4:21}"
date_last_start="$(echo $date_last_start | sed 's/^/[/;s+ +/+;s+ +/+;s+ +:+')"

# для тестированияиспользуем дату из существующего файла лога access.log
date_test='[14/Aug/2019:23:00:00'

# создаем промежуточный файл с выборкой записей из access.log с момента последнего запуска скрипта (1 час назад)
# для использования текущей даты следует заменить переменную $date_test на $date_last_start
while IFS= read -r line
do
	date_read="$(echo $line | awk '{print $4}')"
	if [ "$date_test" \< "$date_read" ]; then
		echo $line >> /tmp/data.txt
	fi
done < access.log

# создаем файл для отправки по почте
echo -e "Текущее время: \t\t\t\t $date_now" > /tmp/report.txt
echo -e "Время последнего запуска скрипта: \t ${date_last_start:1}" >> /tmp/report.txt
echo "IP-адреса с наибольшим количеством запросов:" >> /tmp/report.txt
awk '{print $1}' /tmp/data.txt | sort | uniq -c | sort -rn | head >> /tmp/report.txt
echo "Запрашиваемые URL с наибольшим количеством запросов:" >> /tmp/report.txt
awk '{print $7}' /tmp/data.txt | sort | uniq -c | sort -rn | head >> /tmp/report.txt
echo "Ошибки веб-сервера/приложения:" >> /tmp/report.txt
awk '{print $9}' /tmp/data.txt | sed -e '/1../d' -e '/2../d' -e '/3../d' | sort | uniq -c | sort -rn >> /tmp/report.txt
echo "Коды HTTP ответа:" >> /tmp/report.txt
awk '{print $9}' /tmp/data.txt | sort | uniq -c | sort -rn >> /tmp/report.txt

# отправляем файл по электронной почте на заданную почту и стираем временные файлы
cat /tmp/report.txt | mail -s "hourly report" user@example.iq && rm /tmp/data.txt /tmp/report.txt

# зпроверяем, что скрипт запущен в единственном экземпляре
if (set -o noclobber; echo "$$" >> "lockfile") 2>/dev/null
then
	trap 'echo Процесс выполняется, остановить нельзя' INT
	trap 'rm -f "$lockfile"; exit $?' TERM EXIT
else
	echo "Невозможно получить доступ к файлу $lockfile"
	echo "Файл используется процессом $(cat$lockfile)"
fi
