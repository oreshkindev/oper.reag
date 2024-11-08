#!/usr/bin/env bash

# Проверка, запущен ли скрипт от имени root
if [ "$(id -u)" -ne 0 ]; then
    echo "Необходимы права root для запуска сценария."
    exit 1
fi

# Определение операционной системы и пакетного менеджера
set_package_manager() {
    if [ -f /etc/redhat-release ]; then
        echo "Обнаружена система на базе Red Hat..."
        PACKAGE_MANAGER="yum"
    else
        echo "Неподдерживаемая операционная система."
        exit 1
    fi
}

# Функция для проверки и установки пакета
install_packages() {
    local PACKAGES=("$@")
    local SPELL=false

    for P in "${PACKAGES[@]}"; do
        if ! rpm -q "$P" >/dev/null 2>&1; then
            if [ "$SPELL" = false ]; then
                echo -n "Установить $P? (да / * (для всех) или (нет): "
                read -r RESPONSE
            fi

            if [ "$RESPONSE" = "Да" ] || [ "$RESPONSE" = "да" ] || [ "$RESPONSE" = "д" ] || [ "$SPELL" = true ]; then
                echo "Устанавливаем $P..."
                if [ "$PACKAGE_MANAGER" = "yum" ]; then
                    yum install -y "$P"
                fi
                if [ $? -ne 0 ]; then
                    echo "Не удалось установить $P. Проверьте подключение к интернету и повторите попытку."
                    exit 1
                fi
            elif [ "$RESPONSE" = "*" ]; then
                SPELL=true
                echo "Устанавливаем $P..."
                if [ "$PACKAGE_MANAGER" = "yum" ]; then
                    yum install -y "$P"
                fi
                if [ $? -ne 0 ]; then
                    echo "Не удалось установить $P. Проверьте подключение к интернету и повторите попытку."
                    exit 1
                fi
            else
                echo "$P пропущен."
            fi
        else
            echo "$P уже установлен."
        fi
    done
}

install_migrations() {
    echo "Установка миграций..."
    for migration in /opt/oper.reag/backend/migrations/*.sql; do
        echo "Выполнение миграции $migration..."
        sudo -u postgres psql -d postgres -f "$migration"
        if [ $? -ne 0 ]; then
            echo "Ошибка при выполнении миграции $migration."
            exit 1
        fi
    done
}

install_asterisk() {

    cd
    echo "Проверка и установка зависимостей для Asterisk..."

    local PACKAGES=(
        "epel-release"
        "chkconfig"
        "libedit-devel"
    )

    install_packages "${PACKAGES[@]}"

    echo "Установка Asterisk..."

    # wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-20-current.tar.gz

    wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz

    tar zxvf asterisk-22-current.tar.gz

    rm -rf asterisk-22-current.tar.gz

    cd asterisk-22*/

    contrib/scripts/install_prereq install

    ./configure --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled

    make

    make install

    make samples

    mkdir /etc/asterisk/samples

    mv /etc/asterisk/*.* /etc/asterisk/samples/

    make basic-pbx

    touch /usr/lib/systemd/system/asterisk.service

    cat <<'EOF' >/usr/lib/systemd/system/asterisk.service
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
EOF

    echo "Asterisk установлен."

    systemctl enable asterisk.service

    systemctl start asterisk

    echo "Конфигурация Asterisk..."

    # Создание пользовательских конфигурационных файлов
    ASTERISK_DIR="/etc/asterisk"

    touch "$ASTERISK_DIR/pjsip_custom.conf"
    touch "$ASTERISK_DIR/extensions_custom.conf"

    # Добавление импорта пользовательских конфигураций
    echo "#include pjsip_custom.conf" >>"$ASTERISK_DIR/pjsip.conf"
    echo "#include extensions_custom.conf" >>"$ASTERISK_DIR/extensions.conf"

    # Генерация сложного пароля для AMI пользователя
    AMI_PASSWORD=$(openssl rand -base64 16)

    echo "*------------------------------------------------------*"
    echo ""
    echo "Пароль пользователя AMI: $AMI_PASSWORD"
    echo ""
    echo "*------------------------------------------------------*"

    sed -i 's/^;enabled = no/enabled = yes/' "$ASTERISK_DIR/manager.conf"

    # Добавление AMI пользователя
    cat <<EOL >>"$ASTERISK_DIR/manager.conf"
[admin]
secret = $AMI_PASSWORD
read = all
write = all
EOL

    echo "Конфигурация AMI добавлена в manager.conf."

    # Обновляем пароль в окружении AMI сервиса
    sed -i "s|export SECRET=.*|export SECRET=\"$AMI_PASSWORD\"|" /opt/oper.reag/backend-ami/env.sh

    echo "Добавление Asterisk в автозапуск и запуск службы..."
    systemctl enable asterisk

    systemctl restart asterisk

    echo "Конфигурация Asterisk завершена."
}

configure_postgresql() {
    echo "Настройка конфигурации postgresql-16..."

    echo "Инициализируем базу данных..."
    postgresql-16-setup initdb

    echo "Добавляем сервис postgresql-16 в автозапуск..."
    systemctl enable postgresql-16.service --now

    echo "Открываем все адреса для прослушивания..."
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/16/data/postgresql.conf

    echo "host postgres all 94.233.73.24/32 md5" >>/var/lib/pgsql/16/data/pg_hba.conf

    echo "Генерируем новый пароль для пользователя postgres..."
    ENCRYPTED_PASSWORD=$(openssl rand -base64 12)

    echo "Устанавливаем новый пароль для пользователя postgres..."
    sudo -u postgres psql -c "ALTER USER postgres WITH ENCRYPTED PASSWORD '$ENCRYPTED_PASSWORD';"

    echo "*------------------------------------------------------*"
    echo ""
    echo "Пароль пользователя postgres: $ENCRYPTED_PASSWORD"
    echo ""
    echo "*------------------------------------------------------*"

    # Обновляем пароль в окружении бэкенда
    sed -i "s|export DATABASE_URL=.*|export DATABASE_URL=\"postgres://postgres:$ENCRYPTED_PASSWORD@localhost:5432/postgres?sslmode=disable\"|" /opt/oper.reag/backend/env.sh

    echo "Открываем порт 5432 для внешнего доступа..."
    sudo firewall-cmd --permanent --add-port=5432/tcp
    sudo firewall-cmd --reload

    echo "Перезапуск службы postgresql-16..."
    systemctl restart postgresql-16.service
}

configure_apache() {
    echo "Настройка конфигурации apache..."

    # Создание файла конфигурации frontend.conf
    cat <<EOL >/etc/httpd/conf.d/frontend.conf
<VirtualHost *:80>
    ServerName frontend  # Замените на доменное имя или IP-адрес

    DocumentRoot /opt/oper.reag/frontend  # Путь к собранным файлам фронтенда

    <Directory /opt/oper.reag/frontend>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    # Проксирование на бэкенд
    ProxyPass /v1 http://localhost:9000
    ProxyPassReverse /v1 http://localhost:9000

    # Проксирование на сервис AMI
    ProxyPass /ami http://localhost:9002
    ProxyPassReverse /ami http://localhost:9002
</VirtualHost>
EOL

    echo "Проверка конфигурации apache на наличие ошибок..."
    apachectl configtest

    if [ $? -eq 0 ]; then
        echo "Конфигурация apache корректна. Перезапуск apache..."
        systemctl restart httpd
    else
        echo "Ошибка в конфигурации apache. Пожалуйста, проверьте файл /etc/httpd/conf.d/frontend.conf"
    fi

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
}

configure_nginx() {
    echo "Настройка конфигурации nginx..."

    # Создание файла конфигурации frontend.conf
    cat <<EOL >/etc/nginx/conf.d/frontend.conf
server {
    listen 80;
    server_name frontend;  # Замените на доменное имя или IP-адрес

    location / {
        root /opt/oper.reag/frontend;  # Путь к собранным файлам фронтенда
        try_files \$uri \$uri/ /index.html;
    }

    location /v1 {
        proxy_pass http://localhost:9000;  # Проксирование на бэкенд
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /ami {
        proxy_pass http://localhost:9002;  # Проксирование на сервис AMI
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOL

    echo "Проверка конфигурации nginx на наличие ошибок..."
    nginx -t

    if [ $? -eq 0 ]; then
        echo "Конфигурация nginx корректна. Перезапуск nginx..."
        systemctl restart nginx
    else
        echo "Ошибка в конфигурации nginx. Пожалуйста, проверьте файл /etc/nginx/conf.d/frontend.conf"
    fi

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
}

configure_backend_service() {
    echo "Создание службы backend.service..."

    # Создание файла backend.service
    cat <<EOL >/etc/systemd/system/backend.service
[Unit]
Description=Backend service
After=network.target

[Service]
EnvironmentFile=/opt/oper.reag/backend/env.sh
ExecStart=/bin/bash -c 'source /opt/oper.reag/backend/env.sh && /opt/oper.reag/backend/bin/backend'
WorkingDirectory=/opt/oper.reag/backend
User=root
Group=wheel
Restart=always
RestartSec=5
StandardOutput=append:/opt/oper.reag/backend/log/backend.log
StandardError=append:/opt/oper.reag/backend/log/backend-error.log
SyslogIdentifier=backend

[Install]
WantedBy=multi-user.target
EOL

    chmod +x /opt/oper.reag/backend/env.sh
    chmod +x /opt/oper.reag/backend/bin/backend

    echo "Перезагрузка systemd для применения изменений..."
    systemctl daemon-reload

    echo "Включение и запуск службы backend.service..."
    systemctl enable backend.service --now

    echo "Служба backend.service успешно создана и запущена."
}

configure_backend_ami_service() {
    echo "Создание службы backend-ami.service..."

    # Создание файла backend.service
    cat <<EOL >/etc/systemd/system/backend-ami.service
[Unit]
Description=Backend AMI service
After=network.target

[Service]
EnvironmentFile=/opt/oper.reag/backend-ami/env.sh
ExecStart=/bin/bash -c 'source /opt/oper.reag/backend-ami/env.sh && /opt/oper.reag/backend-ami/bin/backend-ami'
WorkingDirectory=/opt/oper.reag/backend-ami
User=root
Group=wheel
Restart=always
RestartSec=5
StandardOutput=append:/opt/oper.reag/backend-ami/log/backend.log
StandardError=append:/opt/oper.reag/backend-ami/log/backend-error.log
SyslogIdentifier=backend-ami

[Install]
WantedBy=multi-user.target
EOL

    chmod +x /opt/oper.reag/backend-ami/env.sh
    chmod +x /opt/oper.reag/backend-ami/bin/backend-ami

    echo "Перезагрузка systemd для применения изменений..."
    systemctl daemon-reload

    echo "Включение и запуск службы backend-ami.service..."
    systemctl enable backend-ami.service --now

    echo "Служба backend-ami.service успешно создана и запущена."
}

# Основная логика
main() {
    set_package_manager

    #
    #
    echo "Обновить систему перед установкой необходимых компонентов (да / нет)? (рекомендуется):"
    read -r RESPONSE

    case "$RESPONSE" in
    "Да" | "да" | "д")
        if [ "$PACKAGE_MANAGER" = "yum" ]; then
            yum check-update
        fi
        ;;
    *)
        echo "Продолжаем без обновления компонентов..."
        ;;
    esac

    #
    #
    echo "Необходимо установить веб-сервер (да / нет)? (рекомендуется):"
    read -r RESPONSE
    case "$RESPONSE" in
    "Да" | "да" | "д")
        echo "Какой веб-сервер установить (apache / nginx)?:"
        read -r RESPONSE
        case "$RESPONSE" in
        "apache" | "a")
            install_packages "httpd"

            echo "Произвести первоначальную настройку apache (да / нет)? (рекомендуется):"
            read -r RESPONSE

            case "$RESPONSE" in
            "Да" | "да" | "д")
                configure_apache
                ;;
            *)
                echo "После установки произведите настройку apache"
                ;;
            esac
            ;;
        "nginx" | "n")
            install_packages "nginx"

            echo "Произвести первоначальную настройку nginx (да / нет)? (рекомендуется):"
            read -r RESPONSE

            case "$RESPONSE" in
            "Да" | "да" | "д")
                configure_nginx
                ;;
            *)
                echo "После установки произведите настройку nginx"
                ;;
            esac
            ;;
        *)
            echo "Продолжаем без установки веб-сервера..."
            ;;
        esac
        ;;
    *)
        echo "Настройте веб сервер на свое усмотрение. Скомпилированные исходники будут расположены в /opt/oper.reag/frontend/"
        ;;
    esac

    #
    #
    echo "Использовать Asterisk для работы со сценариями (да / нет)? (рекомендуется):"
    read -r RESPONSE

    case "$RESPONSE" in
    "Да" | "да" | "д")
        install_asterisk
        ;;
    *)
        echo "Будет произведена компиляция бэкенд-сервиса с отключенными сценариями"
        ;;
    esac

    #
    #
    echo "Использовать хранилище Postgresql (да / нет)? (рекомендуется):"
    read -r RESPONSE

    case "$RESPONSE" in
    "Да" | "да" | "д")
        yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm

        yum -qy module disable postgresql

        yum install -y postgresql16-server postgresql16

        echo "Произвести первоначальную настройку Postgresql (да / нет)? (рекомендуется):"
        read -r RESPONSE

        case "$RESPONSE" in
        "Да" | "да" | "д")
            configure_postgresql
            ;;
        *)
            echo "После установки произведите настройку postgresql.conf, pg_hba.conf"
            echo "Замените пароль у пользователя postgres"
            ;;
        esac
        ;;
    *)
        echo "После установки произведите настройку /opt/oper.reag/backend/env.sh"
        ;;
    esac

    #
    #
    echo "Использовать видео-контроллер (да / нет)? (рекомендуется):"
    read -r RESPONSE

    case "$RESPONSE" in
    "Да" | "да" | "д")
        echo "Установка набора инструментов для обработки мультимедийных данных..."
        wget https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz

        tar -xvf ffmpeg-7.1.tar.xz

        cd ffmpeg-7.1

        ./configure --disable-x86asm

        make

        sudo make install
        ;;
    *)
        echo "Будет произведена компиляция бэкенд-сервиса с отключенным видео-контроллером"
        ;;
    esac

    #
    #
    echo "Запустить миграции (да / нет)? (рекомендуется):"
    read -r RESPONSE

    case "$RESPONSE" in
    "Да" | "да" | "д")
        echo "Запуск миграций..."

        install_migrations
        ;;
    *)
        echo "Запустите миграции из директории /opt/oper.reag/backend/migrations/"
        ;;
    esac

    echo "Настройка backend.service..."
    configure_backend_service

    echo "Настройка backend-ami.service..."
    configure_backend_ami_service

    echo "Перезагрузка systemd для применения изменений..."
    systemctl daemon-reload

    echo "Перезагрузка backend.service..."
    systemctl restart backend.service

    echo "Перезагрузка backend-ami.service..."
    systemctl restart backend-ami.service

    echo "Перезагрузка asterisk.service..."
    systemctl restart asterisk.service

    echo "Установка завершена."
    echo "Интерфейс доступен на http://localhost/"
}

main
