<br>
<br>

<p align="center">
  <br>
  <img width="120" src="favicon.svg" alt="Программное обеспечение «Оперативное реагирование»">
  <br>
  <br>
</p>

<p align="center">
Программное обеспечение <br>«Оперативное реагирование»
<br>
<br>
  Версия: 1.0.0
</p>

<br>
<br>

<br>
<br>

### Автоматическая установка и настройка

Копируем репозиторий

```bash
git clone https://github.com/oreshkindev/oper.reag.git /opt/oper.reag
```

Выставляем права для скрипта

```bash
chmod +x /opt/oper.reag/install.sh
```

Запускаем скрипт и выбираем все что нам нужно

```bash
/opt/oper.reag/install.sh
```

Используя установщик, вероятность того что у вас что-то не получится приравнивается к нулю.

<details><summary>### Ручная установка и настройка</summary>

Убедитесь, что вы вводите все команды от имени пользователя «root». Введите «su», затем свой пароль пользователя «root».

```bash
su -
```

Обновите свою систему перед установкой необходимых зависимостей.

```bash
yum check-update
```

#### Отключите SELinux

Обязательно отключите модуль безопасности ядра Linux — SELinux перед установкой.

Команда sestatus покажет текущее состояние SELinux:

```bash
sestatus
```

Результат:

```bash
SELinux status:                 disabled
```

Если статус отличается от результата выше, внесите изменения в /etc/selinux/config

```bash
nano /etc/selinux/config
```

Измените политику действий с принудительного применения на отключенную

```bash
SELINUX=disabled
```

#### Перезагрузка

Для того, чтобы изменения применились, перезагружаем систему

```bash
reboot
```

После перезагрузки команда «sestatus» должна показать, что SELinux отключен

Далее перейдем к настройке веб-сервера который будет отдавать нашу панель управления. Я опишу процесс установки и настройки для apache и nginx, какую выбрать - решать вам.

#### Установка и настройка веб-сервера nginx

Устанавливаем веб-сервер

```bash
yum install -y nginx
```

После установки веб-сервера, его необходимо настроить.

##### Создаем файл конфигурации и добавляем блок

По умолчанию nginx расположен в директории /etc/nginx/ . Замените example на имя, которое ассоциируется с вашим сервисом.

```bash
cat <<EOL >/etc/nginx/conf.d/example.conf
server {
    listen 80;
    listen [::]:80;

    # Замените example.com на доменное имя или ip-адрес сервера
    server_name example.com;

    # Указываем корневую директорию для статических файлов
    root /opt/oper.reag/frontend;

    # Индексный файл по умолчанию
    index index.html;

    # Основная локация для обработки запросов
    location / {
        # Пытаемся найти файл или директорию, если не найдено - перенаправляем на index.html
        try_files $uri $uri/ /index.html;
    }

    # Кэширование статических файлов
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 7d;
        add_header Cache-Control "public, must-revalidate";
    }

    # Проксирование на бэкенд
}
EOL
```

Проверка конфигурации nginx на наличие ошибок

```bash
nginx -t
```

Если видим `syntax is ok` и `test is successful`, значит мы сделали все правильно.

Перезапускаем веб-сервер

```bash
systemctl restart nginx
```

Сообщаем нашему брандмауэру что нужно открыть порт 80 и перезапускаем его

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

На этом первичная конфигурация nginx завершена. Результат можно проверить выполнив команду

```bash
echo "curl http://$(hostname -I | awk '{print $1}')"
```

Или открыть адрес в браузере.

#### Установка и настройка веб-сервера apache

По умолчанию apache расположен в директории /etc/httpd/ . Замените example на имя, которое ассоциируется с вашим сервисом.

```bash
cat <<EOL >/etc/httpd/conf.d/example.conf
<VirtualHost *:80>
    # Замените на доменное имя или ip-адрес сервера
    ServerName example.com

    # Путь к собранным файлам фронтенда
    DocumentRoot /opt/oper.reag/frontend

    # Настройки для директории с фронтендом
    <Directory /opt/oper.reag/frontend>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted

        # Перенаправление всех запросов на index.html, кроме существующих файлов
        RewriteEngine On
        RewriteBase /
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule ^ index.html [L]
    </Directory>

    # Включение кэширования для статического контента
    <IfModule mod_expires.c>
        ExpiresActive On
        ExpiresByType text/css "access plus 1 week"
        ExpiresByType application/javascript "access plus 1 week"
        ExpiresByType image/jpg "access plus 1 month"
        ExpiresByType image/jpeg "access plus 1 month"
        ExpiresByType image/png "access plus 1 month"
        ExpiresByType image/gif "access plus 1 month"
    </IfModule>

    # Проксирование на бэкенд
</VirtualHost>
EOL
```

Проверка конфигурации apache на наличие ошибок

```bash
apachectl configtest
```

Если видим `syntax is ok` и `test is successful`, значит мы сделали все правильно.

Перезапускаем веб-сервер

```bash
systemctl restart httpd
```

Сообщаем нашему брандмауэру что нужно открыть порт 80 и перезапускаем его

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

На этом первичная конфигурация apache завершена. Результат можно проверить выполнив команду

```bash
echo "curl http://$(hostname -I | awk '{print $1}')"
```

Или открыть адрес в браузере.

#### Установка и настройка Asterisk

Установим необходимые зависимости

```bash
yum install -y epel-release chkconfig libedit-devel
```

Сначала загрузите исходники Asterisk. Каталог /usr/src — удобное место для хранения всех ваших установок.

```bash
cd /usr/src

wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz
```

Распаковываем архив в текущую директорию и удаляем его т.к он больше нам не понадобится

```bash
tar zxvf asterisk-22-current.tar.gz

rm -rf asterisk-22-current.tar.gz
```

Прежде чем продолжить установку, нам нужно добавить все зависимости из ранее загруженных репозиториев.

```bash
cd asterisk-22*/

contrib/scripts/install_prereq install
```

Наконец, мы можем настроить asterisk для окончательной сборки.
Поскольку у нас 64-разрядная система, добавляем параметр --libdir=/usr/lib64 для настройки команды.
И так как chan_pjsip требует наличия некоторых дополнительных библиотек, мы добавляем ещё две опции --with-jansson-bundled --with-pjproject-bundled

Далее последует команда нашего конфигуратора:

```bash
./configure --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled
```

После успешного завершения настройки программного обеспечения мы увидим логотип системы в виде звездочки. Невозможно не заметить.

#### Компиляция и установка

Теперь мы можем просто выполнить команду make без параметров и скомпилировать программу. Этот и следующий процесс могут занять несколько минут.

```bash
make
```

Система подскажет вам, что делать дальше. Выполнение make install окончательно установит Asterisk на ваш сервер.

```bash
make install
```

Создаем примеры файлов с помощью команды make samples.

```bash
make samples
```

Переместите файлы примеров в новую папку (например, /etc/asterisk/samples/) и создайте базовую конфигурацию с помощью make basic-pbx.

```bash
mkdir /etc/asterisk/samples

mv /etc/asterisk/*.* /etc/asterisk/samples/

make basic-pbx
```

Asterisk установлен и настроен. К сожалению, пока нет файлов для запуска. Нам нужно использовать systemd для управления службой Asterisk. Можно сделать make config но мы создадим файл asterisk.service и введём в него необходимую информацию.

```bash
cat <<EOL >/usr/lib/systemd/system/asterisk.service
[Unit]
Description=Asterisk PBX and telephony daemon.
#After=network.target
#include these if asterisk need to bind to a specific IP (other than 0.0.0.0)
Wants=network-online.target
After=network-online.target network.target

[Service]
Type=simple
Environment=HOME=/var/lib/asterisk
WorkingDirectory=/var/lib/asterisk
ExecStart=/usr/sbin/asterisk -mqf -C /etc/asterisk/asterisk.conf
ExecReload=/usr/sbin/asterisk -rx 'core reload'
ExecStop=/usr/sbin/asterisk -rx 'core stop now'

LimitCORE=infinity
Restart=always
RestartSec=4

# Prevent duplication of logs with color codes to /var/log/messages
StandardOutput=null

PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL
```

После этого необходимо еще несколько штрихов. Чтобы не трогать системные файлы, создадим в основной директории с Asterisk два файла в которых будут наши эндпоинты и диалпланы. Так же сообщим Asterisk о наличии этих файлов.

```bash
touch "/etc/asterisk/pjsip_custom.conf"

touch "/etc/asterisk/extensions_custom.conf"

echo "#include pjsip_custom.conf" >>"/etc/asterisk/pjsip.conf"

echo "#include extensions_custom.conf" >>"/etc/asterisk/extensions.conf"
```

Нам осталось только создать нового пользователя AMI. Мы используем AMI т.к с ним проще всего работать.
Для начала создадим пароль для пользователя AMI

```bash
echo "$(openssl rand -base64 16)"
```

Затем нам необходимо включить модуль AMI

```bash
sed -i "s^enabled =.*^enabled = yes^" /etc/asterisk/manager.conf
```

```bash
cat <<EOL >/etc/systemd/system/backend-ami.service
[admin]
secret = secret
read = all
write = all
```

```bash
sed -i "s^secret =.*^secret = сгенерированный_пароль^" /etc/asterisk/manager.conf
```

#### Запуск Asterisk

Теперь вы можете добавить службу asterisk в автозагрузку, запустить её и проверить состояние.

```bash
systemctl enable asterisk.service
systemctl start asterisk
systemctl status asterisk
```

#### Установка и настройка PostgreSQL

Подготовим исходники и переопределим пакеты

```bash
yum install -y "https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
```

Отключаем стандартный модуль

```bash
yum -qy module disable postgresql
```

Устанавливаем

```bash
yum install -y postgresql16-server postgresql16
```

#### Настройка PostgreSQL

Первым делом нам нужно инициализировать базу данных. Выполняем в терминале

```bash
postgresql-16-setup initdb
```

Добавляем сервис в автозагрузку

```bash
systemctl enable postgresql-16.service --now
```

Теперь нам необходимо разрешить сервису слушать адреса

```bash
sed -i "s^#listen_addresses = 'localhost'^listen_addresses = '*'^" /var/lib/pgsql/16/data/postgresql.conf
```

И добавляем новый хост для pgAdmin. Вы можете заменить 127.0.0.1 на IP-адрес вашей удаленной машины (если он статический, в противном случае периодически менять) или указать all что не совсем безопасно.

```bash
echo "host    all             all             127.0.0.1/32            md5" >>/var/lib/pgsql/16/data/pg_hba.conf
```

По умолчанию пользователь postgres имеет одноименный пароль. Давайте его изменим

```bash
echo "$(openssl rand -base64 16)"

sudo -u postgres psql -c "ALTER USER postgres WITH ENCRYPTED PASSWORD 'сгенерированный-пароль';"
```

Сообщаем нашему брандмауэру что нужно открыть порт 5432 и перезапускаем его, а заодно и наш сервис

```bash
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --reload

systemctl restart postgresql-16.service
```

На этом установка и настройка PostgreSQL завершена. Вы можете подключиться к базе данных например через pgAdmin.

#### Установка и настройка ffmpeg

ffmpeg очень мощный инструмент для работы с потоковым видео. В нашем проекте он используется для работы с rtsp-потоком камеры. Давайте установим его.

Сначала загрузите исходники ffmpeg. Каталог /usr/src — удобное место для хранения всех ваших установок.

```bash
wget https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz
```

Распаковываем архив в текущую директорию

```bash
tar -xvf ffmpeg-7.1.tar.xz
```

Прежде чем продолжить установку, нам нужно добавить все зависимости из ранее загруженных репозиториев.

```bash
cd ffmpeg-7.1

./configure --disable-x86asm
```

#### Компиляция и установка

Теперь мы можем просто выполнить команду make без параметров и скомпилировать программу. Этот и следующий процесс могут занять около 15 минут.

```bash
make

sudo make install
```

По окончании установки, проверим наличие ffmpeg выполнив команду

```bash
ffmpeg
```

На этом установка и настройка ffmpeg закончена

#### Установка и настройка основного бэкенд сервиса

Ранее мы с вами установили и настроили веб-сервер который отдает нам фронтенд нашего приложения. Но фронтенд не может работать без установленного и настроеного бэкенда. Давайте скачаем его и настроим.

Для начала нам понадобится скопировать необходимый репозиторий

```bash
cd

git clone https://github.com/example/oper.reag.git /opt/oper.reag
```

После клонирования репозитория у нас появилась новая директория /opt/oper.reag с вложенными поддиректориями и файлами. Нас интересует /opt/oper.reag/backend

Создадим системную службу для нашего бэкенда

```bash
cat <<EOL >/etc/systemd/system/backend.service
[Unit]
Description=Oper.reag backend daemon.
Wants=network-online.target
After=network-online.target network.target

[Service]
Type=simple
EnvironmentFile=/opt/oper.reag/backend/env.sh
WorkingDirectory=/opt/oper.reag/backend
ExecStart=/bin/bash -c 'source /opt/oper.reag/backend/env.sh && /opt/oper.reag/backend/bin/backend'
User=root
Group=root
StandardOutput=append:/opt/oper.reag/backend/log/backend.log
StandardError=append:/opt/oper.reag/backend/log/backend-error.log
SyslogIdentifier=backend

LimitCORE=infinity
Restart=always
RestartSec=4

[Install]
WantedBy=multi-user.target
EOL
```

После чего выставим необходимые права для файла с окружением и бинарником

```bash
    chmod 600 /opt/oper.reag/backend/env.sh
    chown root:root /opt/oper.reag/backend/env.sh

    chmod 700 /opt/oper.reag/backend/bin/backend
    chown root:root /opt/oper.reag/backend/bin/backend
```

Теперь перезапустим системные службы и добавим наш сервис в автозапуск

```bash
systemctl daemon-reload

systemctl enable backend.service --now
```

Половина дела сделано. Нам осталось прокинуть проксирование запросов на наш сервис и поправить окружение.

#### Проксирование запросов

Откроем конфигурационный файл нашего веб-сервера и добавим в него содержимое

##### Если apache

```bash
nano /etc/httpd/conf.d/example.conf

<VirtualHost *:80>
    ...

    # Проксирование на бэкенд сервис
    ProxyPass /v1 http://localhost:9000
    ProxyPassReverse /v1 http://localhost:9000
</VirtualHost>
```

##### Если nginx

```bash
nano /etc/nginx/conf.d/example.conf

server {
    ...

    # Проксирование на бэкенд сервис
    location /v1 {
        proxy_pass http://localhost:9000;  # Проксирование на бэкенд
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
```

Мы ранее с вами создавали пароль для нашего postgres пользователя. Давайте укажем его в нашем окружении

```bash
sed -i "s^export DATABASE_URL=.*^export DATABASE_URL=\"postgres://postgres:наш_пароль@localhost:5432/postgres?sslmode=disable\"^" /opt/oper.reag/backend/env.sh
```

Мы ранее с вами создавали пароль для нашего AMI пользователя. Давайте укажем его в нашем окружении

```bash
sed -i "s^export AMI_PASS=.*^export AMI_PASS=\"наш_пароль\"^" /opt/oper.reag/backend/env.sh
```

Нам осталось только запустить его

```bash
systemctl start backend.service
systemctl status backend.service
```

На этом настройка основного бэкенд сервиса закончена.

#### Миграции

Файлы миграции расположены в /opt/oper.reag/backend/migrations

Вы можете использовать утилиту migrate или выполнить следующую команду

```bash
for M in /opt/oper.reag/backend/migrations/*.sql; do
    sudo -u postgres psql -d postgres -f "$M"

    if [ $? -ne 0 ]; then
        print "Ошибка при выполнении миграции $M."
        exit 1
    fi
done
```

Если все прошло успешно, вы увидите новые таблицы в pgAdmin

#### Заключение

Мы настроили с вами веб-сервер, настроили Asterisk, подключили базу данных PostgreSQL, скачали и настроили сервисы в т.ч ffmpeg.
Перезапустим все.

```bash
systemctl daemon-reload

systemctl restart backend.service

systemctl restart backend-ami.service

systemctl restart asterisk.service

systemctl restart postgresql16.service

systemctl restart nginx
```

На этом установка нашей системы завершена.

</details>
