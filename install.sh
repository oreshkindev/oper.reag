#!/usr/bin/env bash

# Проверка, запущен ли скрипт от имени root
if [ "$(id -u)" -ne 0 ]; then
    echo "Необходимы права root для запуска сценария."
    exit 1
fi

# Определение операционной системы и пакетного менеджера
if [ -f /etc/redhat-release ]; then
    echo "Обнаружена система на базе Red Hat..."
else
    echo "Неподдерживаемая операционная система."
    exit 1
fi

# Глобальные переменные
AMI_PASSWORD=""
#
POSTGRESQL_PASSWORD=""
#
IP=$(hostname -I | awk '{print $1}')

install_packages() {

    local PACKAGES=("$@")
    #
    local SPELL=false

    for P in "${PACKAGES[@]}"; do
        if ! rpm -q "$P" >/dev/null 2>&1; then
            if [ "$SPELL" = false ]; then
                echo ""
                echo -n "Установить $P? (да / * (для всех) или (нет): "
                read -r R
            fi

            if [ "$R" = "Да" ] || [ "$R" = "да" ] || [ "$R" = "д" ] || [ "$SPELL" = true ]; then
                echo "Устанавливаем $P..."
                echo ""
                yum install -y "$P"
                if [ $? -ne 0 ]; then
                    echo ""
                    echo "Не удалось установить $P. Проверьте подключение к интернету и повторите попытку."
                    exit 1
                fi
            elif [ "$R" = "*" ]; then
                SPELL=true
                echo ""
                echo "Устанавливаем $P..."
                yum install -y "$P"
                if [ $? -ne 0 ]; then
                    echo ""
                    echo "Не удалось установить $P. Проверьте подключение к интернету и повторите попытку."
                    exit 1
                fi
            else
                echo ""
                echo "$P пропущен."
            fi
        else
            echo ""
            echo "$P уже установлен."
        fi
    done
}

install_migrations() {

    echo "Установка миграций..."
    echo ""
    for migration in /opt/oper.reag/backend/migrations/*.sql; do
        echo "Выполнение миграции $migration..."
        echo ""
        sudo -u postgres psql -d postgres -f "$migration"
        if [ $? -ne 0 ]; then
            echo "Ошибка при выполнении миграции $migration."
            exit 1
        fi
    done
}

install_postgresql() {
    echo "Подготовка postgresql16..."
    echo ""

    install_packages "https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

    echo "Отключение стандартного модуля..."
    echo ""
    yum -qy module disable postgresql

    echo "Установка postgresql16..."
    echo ""

    local PACKAGES=(
        "postgresql16-server"
        "postgresql16"
    )

    install_packages "${PACKAGES[@]}"

    echo "postgresql16 установлен."
    echo ""
}

configure_postgresql() {

    echo "Настройка конфигурации postgresql-16..."
    echo ""

    echo "Инициализируем базу данных..."
    echo ""
    postgresql-16-setup initdb

    echo "Добавляем сервис postgresql-16 в автозапуск..."
    echo ""
    systemctl enable postgresql-16.service --now

    echo "Открываем все адреса для прослушивания..."
    echo ""
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/16/data/postgresql.conf

    echo "host    all             all             127.0.0.1/32            md5" >>/var/lib/pgsql/16/data/pg_hba.conf

    echo "Генерируем новый пароль для пользователя postgres..."
    echo ""
    POSTGRESQL_PASSWORD=$(openssl rand -base64 12)

    echo "Устанавливаем новый пароль для пользователя postgres..."
    echo ""
    sudo -u postgres psql -c "ALTER USER postgres WITH ENCRYPTED PASSWORD '$POSTGRESQL_PASSWORD';"

    echo "*------------------------------------------------------*"
    echo ""
    echo "Пароль пользователя postgres: $POSTGRESQL_PASSWORD"
    echo ""
    echo "*------------------------------------------------------*"

    echo "Обновляем пароль в окружении бэкенда"
    echo ""
    sed -i "s|export DATABASE_URL=.*|export DATABASE_URL=\"postgres://postgres:$POSTGRESQL_PASSWORD@localhost:5432/postgres?sslmode=disable\"|" /opt/oper.reag/backend/env.sh

    echo "Открываем порт 5432 для внешнего доступа..."
    echo ""
    sudo firewall-cmd --permanent --add-port=5432/tcp
    sudo firewall-cmd --reload

    echo "Перезапуск службы postgresql-16..."
    echo ""
    systemctl restart postgresql-16.service
}

configure_apache() {

    echo "Настройка конфигурации apache..."
    echo ""
    touch /etc/httpd/conf.d/frontend.conf

    cat /opt/oper.reag/tmp/etc/httpd/conf.d/frontend.conf >/etc/httpd/conf.d/frontend.conf

    echo "Проверка конфигурации apache на наличие ошибок..."
    echo ""
    apachectl configtest

    if [ $? -eq 0 ]; then
        echo "Конфигурация apache корректна. Перезапуск apache..."
        echo ""
        systemctl restart httpd
    else
        echo "Ошибка в конфигурации apache. Пожалуйста, проверьте файл /etc/httpd/conf.d/frontend.conf"
        echo ""
    fi

    echo "Веб-сервер успешно настроен."
    echo ""
    echo "*------------------------------------------------------*"
    echo ""
    echo "Интерфейс доступен по адресу: http://$IP/"
    echo ""
    echo "*------------------------------------------------------*"
    echo ""

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
}

configure_nginx() {

    echo "Настройка конфигурации nginx..."
    echo ""

    echo "Создание файла конфигурации frontend.conf"
    echo ""
    touch /etc/nginx/conf.d/frontend.conf

    cat /opt/oper.reag/tmp/etc/nginx/conf.d/frontend.conf >/etc/nginx/conf.d/frontend.conf

    echo "Проверка конфигурации nginx на наличие ошибок..."
    echo ""
    nginx -t

    if [ $? -eq 0 ]; then
        echo "Конфигурация nginx корректна. Перезапуск nginx..."
        echo ""
        systemctl restart nginx
    else
        echo "Ошибка в конфигурации nginx. Пожалуйста, проверьте файл /etc/nginx/conf.d/frontend.conf"
        echo ""
    fi

    echo "Веб-сервер успешно настроен."
    echo ""
    echo "*------------------------------------------------------*"
    echo ""
    echo "Интерфейс доступен по адресу: http://$IP/"
    echo ""
    echo "*------------------------------------------------------*"
    echo ""

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
}

configure_backend_service() {
    echo "Создание службы backend.service..."
    echo ""
    touch /etc/systemd/system/backend.service

    cat /opt/oper.reag/tmp/etc/systemd/system/backend.service >/etc/systemd/system/backend.service

    chmod +x /opt/oper.reag/backend/env.sh
    chmod +x /opt/oper.reag/backend/bin/backend

    echo "Перезагрузка systemd для применения изменений..."
    echo ""
    systemctl daemon-reload

    echo "Включение и запуск службы backend.service..."
    echo ""
    systemctl enable backend.service --now

    echo "Служба backend.service успешно создана и запущена."
    echo ""
}

configure_backend_ami_service() {

    echo "Создание службы backend-ami.service..."
    echo ""
    touch /etc/systemd/system/backend-ami.service

    cat /opt/oper.reag/tmp/etc/systemd/system/backend-ami.service >/etc/systemd/system/backend-ami.service

    chmod +x /opt/oper.reag/backend-ami/env.sh
    chmod +x /opt/oper.reag/backend-ami/bin/backend-ami

    echo "Перезагрузка systemd для применения изменений..."
    echo ""
    systemctl daemon-reload

    echo "Включение и запуск службы backend-ami.service..."
    echo ""
    systemctl enable backend-ami.service --now

    echo "Служба backend-ami.service успешно создана и запущена."
    echo ""
}

install_asterisk() {

    cd

    echo "Проверка и установка зависимостей для Asterisk..."
    echo ""

    local PACKAGES=(
        "epel-release"
        "chkconfig"
        "libedit-devel"
    )

    install_packages "${PACKAGES[@]}"

    echo "Установка Asterisk..."
    echo ""

    echo "Скачивание исходников..."
    echo ""
    wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz

    echo "Распаковка архива..."
    echo ""
    tar zxvf asterisk-22-current.tar.gz

    echo "Удаление архива..."
    echo ""
    rm -rf asterisk-22-current.tar.gz

    cd asterisk-22*/

    echo "Установка необходимых зависимостей..."
    echo ""
    contrib/scripts/install_prereq install

    echo ""
    echo "Настройка системы..."
    echo ""
    ./configure --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled

    make

    make install

    make samples

    mkdir /etc/asterisk/samples

    mv /etc/asterisk/*.* /etc/asterisk/samples/

    make basic-pbx

    echo ""
    echo "Создание системной службы..."
    echo ""
    touch /usr/lib/systemd/system/asterisk.service

    echo "Добавляем содержимое..."
    echo ""
    cat /opt/oper.reag/tmp/etc/systemd/system/asterisk.service >/usr/lib/systemd/system/asterisk.service

    echo "Конфигурация Asterisk.Создание пользовательских конфигурационных файлов..."
    echo ""

    DIR="/etc/asterisk"

    touch "$DIR/pjsip_custom.conf"

    touch "$DIR/extensions_custom.conf"

    echo "#include pjsip_custom.conf" >>"$DIR/pjsip.conf"

    echo "#include extensions_custom.conf" >>"$DIR/extensions.conf"

    echo "Генерация пароля для AMI пользователя"
    echo ""

    AMI_PASSWORD=$(openssl rand -base64 16)

    echo "*------------------------------------------------------*"
    echo ""
    echo "Пароль пользователя AMI: $AMI_PASSWORD"
    echo ""
    echo "*------------------------------------------------------*"

    sed -i 's/^;enabled = no/enabled = yes/' "$DIR/manager.conf"

    echo ""
    echo "Добавление AMI пользователя"
    cat /opt/oper.reag/tmp/asterisk/manager.conf >$DIR/manager.conf

    sed -i 's/^secret = secret/secret = '$AMI_PASSWORD'/' "$DIR/manager.conf"

    echo ""
    echo "Конфигурация AMI добавлена в manager.conf."
    echo ""

    echo "Обновляем пароль в окружении AMI сервиса"
    echo ""
    sed -i "s|export SECRET=.*|export SECRET=\"$AMI_PASSWORD\"|" /opt/oper.reag/backend-ami/env.sh

    echo "Asterisk установлен. Запускаю службы..."
    echo ""

    systemctl enable asterisk.service

    systemctl start asterisk

    echo "Конфигурация Asterisk завершена."
}

# Основная логика
main() {

    #
    #
    echo ""
    echo "Обновить систему перед установкой необходимых компонентов (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        yum check-update
        ;;
    *)
        echo ""
        echo "Продолжаем без обновления компонентов..."
        ;;
    esac

    #
    #
    echo ""
    echo "Необходимо установить веб-сервер (да / нет)? (рекомендуется):"
    read -r R
    case "$R" in
    "Да" | "да" | "д")
        echo ""
        echo "Какой веб-сервер установить (apache / nginx)?:"
        read -r R
        case "$R" in
        "apache" | "a")
            install_packages "httpd"

            echo ""
            echo "Произвести первоначальную настройку apache (да / нет)? (рекомендуется):"
            read -r R

            case "$R" in
            "Да" | "да" | "д")
                configure_apache
                ;;
            *)
                echo ""
                echo "После установки произведите настройку apache"
                ;;
            esac
            ;;
        "nginx" | "n")
            install_packages "nginx"

            echo ""
            echo "Произвести первоначальную настройку nginx (да / нет)? (рекомендуется):"
            read -r R

            case "$R" in
            "Да" | "да" | "д")
                configure_nginx
                ;;
            *)
                echo ""
                echo "После установки произведите настройку nginx"
                ;;
            esac
            ;;
        *)
            echo ""
            echo "Продолжаем без установки веб-сервера..."
            ;;
        esac
        ;;
    *)
        echo ""
        echo "Настройте веб сервер на свое усмотрение. Скомпилированные исходники будут расположены в /opt/oper.reag/frontend/"
        ;;
    esac

    #
    #
    echo ""
    echo "Использовать Asterisk для работы со сценариями (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        install_asterisk
        ;;
    *)
        echo ""
        echo "Будет произведена компиляция бэкенд-сервиса с отключенными сценариями"
        ;;
    esac

    #
    #
    echo ""
    echo "Использовать хранилище Postgresql (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        install_postgresql

        echo ""
        echo "Произвести первоначальную настройку Postgresql (да / нет)? (рекомендуется):"
        read -r R

        case "$R" in
        "Да" | "да" | "д")
            configure_postgresql
            ;;
        *)
            echo ""
            echo "После установки произведите настройку postgresql.conf, pg_hba.conf"
            echo "Замените пароль у пользователя postgres"
            ;;
        esac
        ;;
    *)
        echo ""
        echo "После установки произведите настройку /opt/oper.reag/backend/env.sh"
        ;;
    esac

    #
    #
    echo ""
    echo "Использовать видео-контроллер (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        echo ""
        echo "Установка набора инструментов для обработки мультимедийных данных..."
        wget https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz

        tar -xvf ffmpeg-7.1.tar.xz

        cd ffmpeg-7.1

        ./configure --disable-x86asm

        make

        sudo make install
        ;;
    *)
        echo ""
        echo "Будет произведена компиляция бэкенд-сервиса с отключенным видео-контроллером"
        ;;
    esac

    #
    #
    echo ""
    echo "Запустить миграции (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        echo ""
        echo "Запуск миграций..."

        install_migrations
        ;;
    *)
        echo ""
        echo "Запустите миграции из директории /opt/oper.reag/backend/migrations/"
        ;;
    esac

    echo ""
    echo "Настройка backend.service..."
    configure_backend_service

    echo ""
    echo "Настройка backend-ami.service..."
    configure_backend_ami_service

    echo ""
    echo "Перезагрузка systemd для применения изменений..."
    systemctl daemon-reload

    echo ""
    echo "Перезагрузка backend.service..."
    systemctl restart backend.service

    echo ""
    echo "Перезагрузка backend-ami.service..."
    systemctl restart backend-ami.service

    echo ""
    echo "Перезагрузка asterisk.service..."
    systemctl restart asterisk.service

    echo ""
    echo "Установка завершена."
    echo ""
    echo "*------------------------------------------------------*"
    echo ""
    echo "Пароль пользователя postgres: $POSTGRESQL_PASSWORD"
    echo ""
    echo "*------------------------------------------------------*"
    echo ""
    echo "Пароль пользователя AMI: $AMI_PASSWORD"
    echo ""
    echo "*------------------------------------------------------*"
    echo ""
    echo "Интерфейс доступен по адресу: http://$IP/"
    echo ""
    echo "*------------------------------------------------------*"
    echo ""
}

main
