#!/usr/bin/env bash

print() {
    local header="$1"

    echo -e "\n$header\n"
}

#
if [ "$(id -u)" -ne 0 ]; then
    print "Необходимы права root для запуска сценария."
    exit 1
fi

#
if [ -f /etc/redhat-release ]; then
    print "Система на базе RED HAT..."
else
    print "Неподдерживаемая операционная система."
    exit 1
fi

#
#
AMI_PASSWORD=""
#
#
POSTGRESQL_PASSWORD=""
#
#
IP=$(hostname -I | awk '{print $1}')
#
#
SOURCE_FOLDER="/opt/oper.reag"

install_packages() {
    local PACKAGES=("$@")
    #
    #
    local SPELL=false

    for P in "${PACKAGES[@]}"; do
        if ! rpm -q "$P" >/dev/null 2>&1; then
            if [ "$SPELL" = false ]; then
                print -n "Установить $P? (да / * (для всех) или (нет): "
                read -r R
            fi

            if [ "$R" = "Да" ] || [ "$R" = "да" ] || [ "$R" = "д" ] || [ "$SPELL" = true ]; then
                print "Устанавливаем $P..."

                yum install -y "$P"

                if [ $? -ne 0 ]; then
                    print "Не удалось установить $P. Проверьте подключение к интернету и повторите попытку."
                    exit 1
                fi
            elif [ "$R" = "*" ]; then
                SPELL=true

                print "Устанавливаем $P..."

                yum install -y "$P"

                if [ $? -ne 0 ]; then
                    print "Не удалось установить $P. Проверьте подключение к интернету и повторите попытку."
                    exit 1
                fi
            else
                print "$P пропущен."
            fi
        else
            print "$P уже установлен."
        fi
    done
}

install_migrations() {
    print "Выполнение миграции..."

    for M in $SOURCE_FOLDER/backend/migrations/*.sql; do
        print "Выполнение миграции $M..."

        sudo -u postgres psql -d postgres -f "$M"

        if [ $? -ne 0 ]; then
            print "Ошибка при выполнении миграции $M."
            exit 1
        fi
    done
}

install_postgresql() {
    print "Подготовка postgresql16..."

    install_packages "https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

    print "Отключение стандартного модуля..."
    yum -qy module disable postgresql

    print "Установка postgresql16..."

    local PACKAGES=(
        "postgresql16-server"
        "postgresql16"
    )

    install_packages "${PACKAGES[@]}"

    print "postgresql16 установлен."
}

configure_postgresql() {

    print "Настройка конфигурации postgresql-16..."

    print "Инициализируем базу данных..."
    postgresql-16-setup initdb

    print "Добавляем сервис postgresql-16 в автозапуск..."
    systemctl enable postgresql-16.service --now

    print "Открываем все адреса для прослушивания..."
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/16/data/postgresql.conf

    echo "host    all             all             127.0.0.1/32            md5" >>/var/lib/pgsql/16/data/pg_hba.conf

    print "Генерируем новый пароль для пользователя postgres..."
    POSTGRESQL_PASSWORD=$(openssl rand -base64 12)

    print "Устанавливаем новый пароль для пользователя postgres..."
    sudo -u postgres psql -c "ALTER USER postgres WITH ENCRYPTED PASSWORD '$POSTGRESQL_PASSWORD';"

    print "*------------------------------------------------------*"
    print "Пароль пользователя postgres: $POSTGRESQL_PASSWORD"
    print "*------------------------------------------------------*"

    print "Обновляем пароль в окружении бэкенда"
    sed -i "s|export DATABASE_URL=.*|export DATABASE_URL=\"postgres://postgres:$POSTGRESQL_PASSWORD@localhost:5432/postgres?sslmode=disable\"|" $SOURCE_FOLDER/backend/env.sh

    print "Открываем порт 5432 для внешнего доступа..."
    sudo firewall-cmd --permanent --add-port=5432/tcp
    sudo firewall-cmd --reload

    print "Перезапуск службы postgresql-16..."
    systemctl restart postgresql-16.service
}

configure_apache() {

    print "Настройка конфигурации apache..."
    touch /etc/httpd/conf.d/frontend.conf

    cat $SOURCE_FOLDER/tmp/etc/httpd/conf.d/frontend.conf >/etc/httpd/conf.d/frontend.conf

    print "Проверка конфигурации apache на наличие ошибок..."
    apachectl configtest

    if [ $? -eq 0 ]; then
        print "Конфигурация apache корректна. Перезапуск apache..."
        systemctl restart httpd
    else
        print "Ошибка в конфигурации apache. Пожалуйста, проверьте файл /etc/httpd/conf.d/frontend.conf"
    fi

    print "Веб-сервер успешно настроен."
    print "*------------------------------------------------------*"
    print "Интерфейс доступен по адресу: http://$IP/"
    print "*------------------------------------------------------*"

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
}

configure_nginx() {

    print "Настройка конфигурации nginx..."

    print "Создание файла конфигурации frontend.conf"
    touch /etc/nginx/conf.d/frontend.conf

    cat $SOURCE_FOLDER/tmp/etc/nginx/conf.d/frontend.conf >/etc/nginx/conf.d/frontend.conf

    print "Проверка конфигурации nginx на наличие ошибок..."
    nginx -t

    if [ $? -eq 0 ]; then
        print "Конфигурация nginx корректна. Перезапуск nginx..."
        systemctl restart nginx
    else
        print "Ошибка в конфигурации nginx. Пожалуйста, проверьте файл /etc/nginx/conf.d/frontend.conf"
    fi

    print "Веб-сервер успешно настроен."
    print "*------------------------------------------------------*"
    print "Интерфейс доступен по адресу: http://$IP/"
    print "*------------------------------------------------------*"

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
}

configure_backend_service() {
    print "Создание службы backend.service..."
    touch /etc/systemd/system/backend.service

    cat $SOURCE_FOLDER/tmp/etc/systemd/system/backend.service >/etc/systemd/system/backend.service

    chmod +x $SOURCE_FOLDER/backend/env.sh
    chmod +x $SOURCE_FOLDER/backend/bin/backend

    print "Перезагрузка systemd для применения изменений..."
    systemctl daemon-reload

    print "Включение и запуск службы backend.service..."
    systemctl enable backend.service --now

    print "Служба backend.service успешно создана и запущена."
}

configure_backend_ami_service() {

    print "Создание службы backend-ami.service..."
    touch /etc/systemd/system/backend-ami.service

    cat $SOURCE_FOLDER/tmp/etc/systemd/system/backend-ami.service >/etc/systemd/system/backend-ami.service

    chmod +x $SOURCE_FOLDER/backend-ami/env.sh
    chmod +x $SOURCE_FOLDER/backend-ami/bin/backend-ami

    print "Перезагрузка systemd для применения изменений..."
    systemctl daemon-reload

    print "Включение и запуск службы backend-ami.service..."
    systemctl enable backend-ami.service --now

    print "Служба backend-ami.service успешно создана и запущена."
}

install_asterisk() {

    cd

    print "Проверка и установка зависимостей для Asterisk..."

    local PACKAGES=(
        "epel-release"
        "chkconfig"
        "libedit-devel"
    )

    install_packages "${PACKAGES[@]}"

    print "Установка Asterisk..."

    print "Скачивание исходников..."
    wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz

    print "Распаковка архива..."
    tar zxvf asterisk-22-current.tar.gz

    print "Удаление архива..."
    rm -rf asterisk-22-current.tar.gz

    cd asterisk-22*/

    print "Установка необходимых зависимостей..."
    contrib/scripts/install_prereq install

    print "Настройка системы..."
    ./configure --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled

    make

    make install

    make samples

    mkdir /etc/asterisk/samples

    mv /etc/asterisk/*.* /etc/asterisk/samples/

    make basic-pbx

    print "Создание системной службы..."
    touch /usr/lib/systemd/system/asterisk.service

    print "Добавляем содержимое..."
    cat $SOURCE_FOLDER/tmp/etc/systemd/system/asterisk.service >/usr/lib/systemd/system/asterisk.service

    print "Конфигурация Asterisk.Создание пользовательских конфигурационных файлов..."

    DIR="/etc/asterisk"

    touch "$DIR/pjsip_custom.conf"

    touch "$DIR/extensions_custom.conf"

    echo "#include pjsip_custom.conf" >>"$DIR/pjsip.conf"

    echo "#include extensions_custom.conf" >>"$DIR/extensions.conf"

    print "Генерация пароля для AMI пользователя"

    AMI_PASSWORD=$(openssl rand -base64 16)

    print "*------------------------------------------------------*"
    print "Пароль пользователя AMI: $AMI_PASSWORD"
    print "*------------------------------------------------------*"

    sed -i 's/^;enabled = no/enabled = yes/' "$DIR/manager.conf"

    print "Добавление AMI пользователя"
    cat $SOURCE_FOLDER/tmp/asterisk/manager.conf >$DIR/manager.conf

    sed -i 's/^secret = secret/secret = '$AMI_PASSWORD'/' "$DIR/manager.conf"

    print "Конфигурация AMI добавлена в manager.conf."

    print "Обновляем пароль в окружении AMI сервиса"
    sed -i "s|export SECRET=.*|export SECRET=\"$AMI_PASSWORD\"|" $SOURCE_FOLDER/backend-ami/env.sh

    print "Asterisk установлен. Запускаю службы..."

    systemctl enable asterisk.service

    systemctl start asterisk

    print "Конфигурация Asterisk завершена."
}

# Основная логика
main() {

    #
    #
    print "Обновить системные компоненты перед установкой (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        yum check-update
        ;;
    *)
        print "Продолжаем без обновления системных компонентов..."
        ;;
    esac

    #
    #
    print "Установить веб-сервер (да / нет)? (рекомендуется):"
    read -r R
    case "$R" in
    "Да" | "да" | "д")
        print "Какой веб-сервер установить (apache / nginx)?:"
        read -r R
        case "$R" in
        "apache" | "a")
            install_packages "httpd"

            print "Произвести первоначальную настройку apache (да / нет)? (рекомендуется):"
            read -r R

            case "$R" in
            "Да" | "да" | "д")
                configure_apache
                ;;
            *)
                print "После установки произведите настройку apache"
                ;;
            esac
            ;;
        "nginx" | "n")
            install_packages "nginx"

            print "Произвести первоначальную настройку nginx (да / нет)? (рекомендуется):"
            read -r R

            case "$R" in
            "Да" | "да" | "д")
                configure_nginx
                ;;
            *)
                print "После установки произведите настройку nginx"
                ;;
            esac
            ;;
        *)
            print "Продолжаем без установки веб-сервера..."
            ;;
        esac
        ;;
    *)
        print "Настройте веб сервер на свое усмотрение. Скомпилированные исходники будут расположены в $SOURCE_FOLDER/frontend/"
        ;;
    esac

    #
    #
    print "Использовать Asterisk для работы со сценариями (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        install_asterisk
        ;;
    *)
        print "Будет произведена компиляция бэкенд-сервиса с отключенными сценариями"
        ;;
    esac

    #
    #
    print "Использовать хранилище Postgresql (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        install_postgresql

        print "Произвести первоначальную настройку Postgresql (да / нет)? (рекомендуется):"
        read -r R

        case "$R" in
        "Да" | "да" | "д")
            configure_postgresql
            ;;
        *)
            print "После установки произведите настройку postgresql.conf, pg_hba.conf"
            print "Замените пароль у пользователя postgres"
            ;;
        esac
        ;;
    *)
        print "После установки произведите настройку $SOURCE_FOLDER/backend/env.sh"
        ;;
    esac

    #
    #
    print "Использовать видео-контроллер (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        print "Установка набора инструментов для обработки мультимедийных данных..."
        wget https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz

        tar -xvf ffmpeg-7.1.tar.xz

        cd ffmpeg-7.1

        ./configure --disable-x86asm

        make

        sudo make install
        ;;
    *)
        print "Будет произведена компиляция бэкенд-сервиса с отключенным видео-контроллером"
        ;;
    esac

    #
    #
    print "Запустить миграции (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    "Да" | "да" | "д")
        print "Запуск миграций..."

        install_migrations
        ;;
    *)
        print "Запустите миграции из директории $SOURCE_FOLDER/backend/migrations/"
        ;;
    esac

    print "Настройка backend.service..."
    configure_backend_service

    print "Настройка backend-ami.service..."
    configure_backend_ami_service

    print "Перезагрузка systemd для применения изменений..."
    systemctl daemon-reload

    print "Перезагрузка backend.service..."
    systemctl restart backend.service

    print "Перезагрузка backend-ami.service..."
    systemctl restart backend-ami.service

    print "Перезагрузка asterisk.service..."
    systemctl restart asterisk.service

    print "Удаляем временные файлы..."
    rm -rf $SOURCE_FOLDER/tmp

    print "Установка завершена."
    print "*------------------------------------------------------*"
    print "Пароль пользователя postgres: $POSTGRESQL_PASSWORD"
    print "*------------------------------------------------------*"
    print "Пароль пользователя AMI: $AMI_PASSWORD"
    print "*------------------------------------------------------*"
    print "Интерфейс доступен по адресу: http://$IP/"
    print "*------------------------------------------------------*"
}

main
