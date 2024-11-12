#!/usr/bin/env bash

# Проверяем на суперпользователя для выполнения необходимых команд
if [ "$(id -u)" -ne 0 ]; then
    echo "Необходимы права root для запуска сценария."
    exit 1
fi

# Ищем признаки Red Hat Enterprise Linux
if [ ! -f /etc/redhat-release ]; then
    echo "Неподдерживаемая операционная система."
    exit 1
fi

cat <<EOL

                 ..............
              .....................
           ..........................
         ..............................
        ...............  ................
       ...........             ...........
     ..........                  ......
     .........                    ..
    .........                  .....
    ........                .........
    ........             ............
    ........                .........
    .........                  .....
     .........                    ..
     ..........                  ......
       ...........             ...........
        ...............  ................
         ..............................
           ..........................
              .....................
                 ..............


              Программное обеспечение
            «Оперативное реагирование»

                  Версия: 1.0.0

EOL

# Установка указанных пакетов.
# Параметры:
#   "$@": Список пакетов для установки.
os_install() {
    local packages=("$@")

    for p in "${packages[@]}"; do
        if rpm -q "$p" >/dev/null 2>&1; then
            echo ""
            echo "$p уже установлен."
            os_select "Обновить?" "Да" "Нет" "Принудительно"
            case $? in
            1)
                echo ""
                echo "Обновляем..."
                yum update -y "$p"
                ;;
            2)
                echo ""
                echo "Продолжаем без обновления..."
                continue
                ;;
            3)
                echo ""
                echo "Устанавливаем $p..."
                if ! yum install -y "$p"; then
                    echo ""
                    echo "Не удалось установить $p. Проверьте подключение к интернету и повторите попытку."
                    exit 1
                fi
                ;;
            esac
        fi

        if [[ "$p" == http* ]]; then
            echo ""
            echo "Устанавливаем пакет из URL: $p"
            if ! yum install -y "$p"; then
                echo ""
                echo "Не удалось установить пакет из $p. Проверьте подключение к интернету и повторите попытку."
                exit 1
            fi
            continue
        fi

        echo ""
        echo "Пакет $p не найден среди установленных. Ищем в репозитории..."

        if ! yum info "$p" >/dev/null 2>&1; then
            echo ""
            echo "Пакет $p не найден в репозитории."
            echo ""
            echo -n "Введите имя пакета для установки (оставьте поле пустым, чтобы пропустить): "
            read -r r

            if [ -n "$r" ]; then
                p="$r"
            else
                echo ""
                echo "$p пропускаем..."
                continue
            fi
        fi
        echo ""
        echo "Устанавливаем $p..."
        if ! yum install -y "$p"; then
            echo ""
            echo "Не удалось установить $p. Проверьте подключение к интернету и повторите попытку."
            exit 1
        fi
    done
}

# Функция экранирования всех специальных символов
os_urlencode() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    for ((pos = 0; pos < strlen; pos++)); do
        c=${string:$pos:1}
        case "$c" in
        [-_.~a-zA-Z0-9]) o="${c}" ;;
        *) printf -v o '%%%02x' "'$c" ;;
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

# Выбор действия
# Параметры:
#   $1: Строка с сообщением для пользователя.
#   $@: Список опций для выбора.
# Возвращает:
#   Индекс выбранной опции (начиная с 1).
os_select() {
    local prompt="$1"
    shift
    local options=("$@")
    local choice

    while true; do
        echo ""
        echo "$prompt: "

        for i in "${!options[@]}"; do
            echo ""
            echo "$((i + 1)). ${options[i]}"
        done
        echo ""
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            return $choice
        else
            echo ""
            echo "Неверный выбор. Пожалуйста, выберите допустимый вариант."
        fi
    done
}

# Обновления системных компонентов
os_update() {
    os_select "Обновить системные компоненты?" "Да" "Нет"
    case $? in
    1)
        if yum check-update; then
            echo ""
            echo "Системные компоненты успешно обновлены."
        else
            echo ""
            echo "Ошибка при обновлении системных компонентов."
        fi
        ;;
    2)
        echo ""
        echo "Продолжаем без обновления системных компонентов..."
        ;;
    esac
}

#
# Генерация случайного пароля длиной 24 байта, для пользователя AMI.
SE_PASS_AMI=$(openssl rand -base64 24)
#
# Генерация случайного пароля длиной 24 байта, для пользователя postgres.
SE_PASS_POSTGRES=$(openssl rand -base64 24)
#
# Получаем ip-адрес сервера для вывода в терминал.
SE_HOST=$(hostname -I | awk '{print $1}')
#
# Директория содержащая исходники
SE_SOURCE="/opt/oper.reag"

# Конфигурация веб-сервера apache
setup_apache_cfg() {
    # Проверяем наличие временного файла конфигурации
    if [ -f "$SE_SOURCE/tmp/etc/httpd/conf.d/example.conf" ]; then
        # Копируем файл в директорию конфигураций httpd
        cp "$SE_SOURCE/tmp/etc/httpd/conf.d/example.conf" /etc/httpd/conf.d/example.conf
    else
        echo ""
        echo "Файл конфигурации $SE_SOURCE/tmp/etc/httpd/conf.d/example.conf не найден."
        exit 1
    fi

    # Изменяем host
    sed -i "s^ServerName example.com^ServerName $SE_HOST:80^" /etc/httpd/conf.d/example.conf
    if [ $? -ne 0 ]; then
        echo ""
        echo "Ошибка при изменении файла конфигурации Apache."
        exit 1
    fi

    # Изменяем путь к основной директории фронтенда
    sed -i "s^DocumentRoot /var/www/example.com/html^DocumentRoot $SE_SOURCE/frontend^" /etc/httpd/conf.d/example.conf
    if [ $? -ne 0 ]; then
        echo ""
        echo "Ошибка при изменении файла конфигурации Apache."
        exit 1
    fi

    # Аналогично
    sed -i "s^<Directory /var/www/example.com/html>^<Directory $SE_SOURCE/frontend>^" /etc/httpd/conf.d/example.conf
    if [ $? -ne 0 ]; then
        echo ""
        echo "Ошибка при изменении файла конфигурации Apache."
        exit 1
    fi

    echo ""
    echo "Проверяем конфигурацию apache..."
    if apachectl configtest; then
        echo ""
        echo "Конфигурация apache корректна. Перезапуск apache..."
        systemctl restart httpd
        if [ $? -ne 0 ]; then
            echo ""
            echo "Ошибка при перезапуске Apache."
            exit 1
        fi
    else
        echo ""
        echo "Ошибка в конфигурации apache. Пожалуйста, проверьте файл /etc/httpd/conf.d/example.conf"
        exit 1
    fi

    echo ""
    echo "Включаем firewall..."
    sudo systemctl start firewalld
    sudo systemctl enable firewalld

    echo ""
    echo "Открываем порт :80"
    if ! sudo firewall-cmd --list-services | grep -q http; then
        if ! sudo firewall-cmd --permanent --add-service=http; then
            echo ""
            echo "Ошибка при открытии порта :80."
            exit 1
        fi
    fi

    if ! sudo firewall-cmd --reload; then
        echo ""
        echo "Ошибка при перезагрузке конфигурации firewall."
        exit 1
    fi

    echo ""
    echo "*------------------------------------------------------*"
    echo ""
    echo -e "Интерфейс доступен по адресу: \e[38;5;111mhttp://$SE_HOST/\e[0m"
    echo ""
    echo "*------------------------------------------------------*"
}

# Конфигурация веб-сервера nginx
setup_nginx_cfg() {
    # Проверяем наличие временного файла конфигурации
    if [ -f "$SE_SOURCE/tmp/etc/nginx/conf.d/example.conf" ]; then
        # Копируем файл в директорию конфигураций nginx
        cp "$SE_SOURCE/tmp/etc/nginx/conf.d/example.conf" /etc/nginx/conf.d/example.conf
    else
        echo ""
        echo "Файл конфигурации $SE_SOURCE/tmp/etc/nginx/conf.d/example.conf не найден."
        exit 1
    fi

    # Изменяем host
    sed -i "s^server_name example.com;^server_name $SE_HOST;^" /etc/nginx/conf.d/example.conf
    if [ $? -ne 0 ]; then
        echo ""
        echo "Ошибка при изменении файла конфигурации nginx."
        exit 1
    fi

    # Изменяем путь к основной директории фронтенда
    sed -i "s^root /var/www/example.com/html;^root $SE_SOURCE/frontend;^" /etc/nginx/conf.d/example.conf
    if [ $? -ne 0 ]; then
        echo ""
        echo "Ошибка при изменении файла конфигурации nginx."
        exit 1
    fi

    echo ""
    echo "Проверяем конфигурацию nginx..."
    if nginx -t; then
        echo ""
        echo "Конфигурация nginx корректна. Перезапуск nginx..."
        systemctl restart nginx
        if [ $? -ne 0 ]; then
            echo ""
            echo "Ошибка при перезапуске nginx."
            exit 1
        fi
    else
        echo ""
        echo "Ошибка в конфигурации nginx. Пожалуйста, проверьте файл /etc/nginx/conf.d/example.conf"
        exit 1
    fi

    echo ""
    echo "Открываем порт :80"
    if ! sudo firewall-cmd --list-services | grep -q http; then
        if ! sudo firewall-cmd --permanent --add-service=http; then
            echo ""
            echo "Ошибка при открытии порта :80."
            exit 1
        fi
    fi

    if ! sudo firewall-cmd --reload; then
        echo ""
        echo "Ошибка при перезагрузке конфигурации firewall."
        exit 1
    fi

    echo ""
    echo "*------------------------------------------------------*"
    echo ""
    echo -e "Интерфейс доступен по адресу: \e[38;5;111mhttp://$SE_HOST/\e[0m"
    echo ""
    echo "*------------------------------------------------------*"
}

# Установка и минимальная конфигурация веб-сервера
install_http_server() {
    os_select "Установить веб-сервер?" "Да" "Нет" "Удалить"
    case $? in
    1)
        os_select "Выберите действие" "apache" "nginx"
        case $? in
        1)
            echo ""
            echo "Устанавливаем apache..."
            os_install "httpd"

            os_select "Произвести минимальную настройку apache?" "Да" "Нет"
            case $? in
            1)
                echo ""
                echo "Настраиваем apache..."
                setup_apache_cfg
                ;;
            2)
                echo ""
                echo "Продолжаем без настройки httpd..."
                ;;
            esac
            ;;
        2)
            echo ""
            echo "Устанавливаем nginx..."
            os_install "nginx"

            os_select "Произвести минимальную настройку nginx?" "Да" "Нет"
            case $? in
            1)
                echo ""
                echo "Настраиваем nginx..."
                setup_nginx_cfg
                ;;
            2)
                echo ""
                echo "Продолжаем без настройки nginx..."
                ;;
            esac
            ;;
        esac
        ;;
    2)
        echo ""
        echo "Продолжаем без установки веб-сервера..."
        ;;
    3)
        os_select "Выберите действие" "apache" "nginx"
        case $? in
        1)
            echo ""
            echo "Удаляем Apache..."
            # Останавливаем службу
            systemctl stop httpd

            # Удаляем Apache
            yum remove -y httpd

            # Очищаем ненужные зависимости
            yum autoremove -y

            # Закрываем порт :80
            if sudo firewall-cmd --list-services | grep -q http; then
                if ! sudo firewall-cmd --permanent --remove-service=http; then
                    echo ""
                    echo "Ошибка при закрытии порта :80."
                fi
                sudo firewall-cmd --reload
            fi
            echo ""
            echo "Apache успешно удален"
            ;;
        2)
            echo ""
            echo "Удаляем nginx..."
            # Останавливаем службу
            systemctl stop nginx

            # Удаляем nginx
            yum remove -y nginx

            # Очищаем ненужные зависимости
            yum autoremove -y

            # Закрываем порт :80
            if sudo firewall-cmd --list-services | grep -q http; then
                if ! sudo firewall-cmd --permanent --remove-service=http; then
                    echo ""
                    echo "Ошибка при закрытии порта :80."
                fi
                sudo firewall-cmd --reload
            fi
            echo ""
            echo "nginx успешно удален"
            ;;
        esac
        ;;
    esac
}

# Конфигурация postgresql
setup_postgresql_cfg() {
    echo ""
    echo "Инициализируем базу данных..."
    postgresql-16-setup initdb

    echo ""
    echo "Добавляем службу postgresql-16 в автозапуск..."
    systemctl enable postgresql-16.service --now

    echo ""
    echo "Открываем адреса для прослушивания..."
    sed -i "s^#listen_addresses = 'localhost'^listen_addresses = '*'^" /var/lib/pgsql/16/data/postgresql.conf

    echo "host    all     all             $SE_HOST/32             md5" >>/var/lib/pgsql/16/data/pg_hba.conf

    echo ""
    echo "Устанавливаем пароль для пользователя postgres..."
    sudo -u postgres psql -c "ALTER USER postgres WITH ENCRYPTED PASSWORD '$SE_PASS_POSTGRES';"

    echo "*------------------------------------------------------*"
    echo ""
    echo -e "Пароль пользователя postgres: \e[38;5;111m$SE_PASS_POSTGRES\e[0m"
    echo ""
    echo "*------------------------------------------------------*"

    echo ""
    echo "Открываем порт :5432"
    if ! sudo firewall-cmd --list-ports | grep -q 5432/tcp; then
        if ! sudo firewall-cmd --permanent --add-port=5432/tcp; then
            echo ""
            echo "Ошибка при открытии порта :5432."
            exit 1
        fi
    fi

    if ! sudo firewall-cmd --reload; then
        echo ""
        echo "Ошибка при перезагрузке конфигурации firewall."
        exit 1
    fi

    echo ""
    echo "Перезапуск службы postgresql-16..."
    systemctl restart postgresql-16.service
}

# Установка и минимальная конфигурация СУБД
install_database_service() {
    os_select "Установить систему управления базой данных (СУБД)?" "Да" "Нет" "Удалить"
    case $? in
    1)
        os_select "Выберите действие" "Postgresql"
        case $? in
        1)
            yum clean all
            echo ""
            echo "Устанавливаем postgresql"
            os_install "https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
            echo ""
            echo "Отключаем встроенный модуль"
            yum -qy module disable postgresql

            os_install "postgresql16-server" "postgresql16"

            os_select "Произвести минимальную настройку postgresql?" "Да" "Нет"
            case $? in
            1)
                echo ""
                echo "Настраиваем СУБД..."
                setup_postgresql_cfg
                ;;
            2)
                echo ""
                echo "Продолжаем без настройки СУБД..."
                ;;
            esac
            ;;
        esac
        ;;
    2)
        echo ""
        echo "Продолжаем без СУБД..."
        ;;
    3)
        os_select "Выберите действие" "Postgresql"
        case $? in
        1)
            echo ""
            echo "Останавливаем службу postgresql-16..."
            systemctl stop postgresql-16.service

            echo ""
            echo "Удаляем postgresql-16 и связанные пакеты..."
            yum remove -y postgresql16-server postgresql16

            echo ""
            echo "Очищаем ненужные зависимости..."
            yum autoremove -y

            echo ""
            echo "Закрываем порт :5432"
            if sudo firewall-cmd --list-ports | grep -q 5432/tcp; then
                if ! sudo firewall-cmd --permanent --remove-port=5432/tcp; then
                    echo ""
                    echo "Ошибка при закрытии порта :5432."
                fi
                sudo firewall-cmd --reload
            fi

            echo ""
            echo "PostgreSQL успешно удален."
            ;;
        esac
        ;;
    esac
}

# Конфигурация бэкенд сервера
setup_backend_server() {
    os_select "Обновить конфигурацию бэкенд-сервера?" "Да" "Нет"
    case $? in
    1)
        # Отключение SELinux
        echo ""
        echo "Отключаем SELinux..."
        sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

        echo ""
        echo "Создание службы backend.service..."
        # Проверяем наличие временного файла конфигурации
        if [ -f "$SE_SOURCE/tmp/etc/systemd/system/backend.service" ]; then
            # Копируем файл в директорию системных служб
            cp "$SE_SOURCE/tmp/etc/systemd/system/backend.service" /etc/systemd/system/backend.service
        else
            echo ""
            echo "Файл конфигурации $SE_SOURCE/tmp/etc/systemd/system/backend.service не найден."
            exit 1
        fi

        # Выставляем необходимые права
        chmod 600 $SE_SOURCE/backend/env.sh
        chown root:root $SE_SOURCE/backend/env.sh

        chmod 700 $SE_SOURCE/backend/bin/backend
        chown root:root $SE_SOURCE/backend/bin/backend

        echo ""
        echo "Обновляем конфигурацию..."
        sed -i "s^EnvironmentFile=.*^EnvironmentFile=$SE_SOURCE/backend/env.sh^" /etc/systemd/system/backend.service

        sed -i "s^WorkingDirectory=.*^WorkingDirectory=$SE_SOURCE/backend^" /etc/systemd/system/backend.service

        sed -i "s^ExecStart=.*^ExecStart=/bin/bash -c 'source $SE_SOURCE/backend/env.sh \&\& $SE_SOURCE/backend/bin/backend'^" /etc/systemd/system/backend.service

        sed -i "s^StandardOutput=.*^StandardOutput=append:$SE_SOURCE/backend/log/backend.log^" /etc/systemd/system/backend.service

        sed -i "s^StandardError=.*^StandardError=append:$SE_SOURCE/backend/log/backend-error.log^" /etc/systemd/system/backend.service

        echo ""
        echo "Обновляем переменные окружения..."

        sed -i "s^export DATABASE_URL=.*^export DATABASE_URL=\"postgres://postgres:$(os_urlencode "$SE_PASS_POSTGRES")@localhost:5432/postgres?sslmode=disable\"^" $SE_SOURCE/backend/env.sh

        sed -i "s^export AMI_PASS=.*^export AMI_PASS=\"$SE_PASS_AMI\"^" $SE_SOURCE/backend/env.sh

        sed -i "s^export MEDIA_PATH=.*^export MEDIA_PATH=\"$SE_SOURCE/frontend/in\"^" $SE_SOURCE/backend/env.sh

        os_select "Выполнить миграции?" "Да" "Нет"
        case $? in
        1)

            echo ""
            echo "Применяем миграции..."
            for M in $SE_SOURCE/backend/migrations/*.sql; do
                sudo -u postgres psql -d postgres -f "$M"

                if [ $? -ne 0 ]; then
                    echo ""
                    print "Ошибка при выполнении миграции $M."
                    exit 1
                fi
            done
            ;;
        2)
            echo ""
            echo "Продолжаем без миграций..."
            ;;
        esac

        echo ""
        echo "Перезагрузка systemd для применения изменений..."
        systemctl daemon-reload

        echo "Перезапуск службы postgresql-16..."
        systemctl restart backend.service

        echo ""
        echo "Включение и запуск службы backend.service..."
        systemctl enable backend.service --now

        echo ""
        echo "Служба backend.service успешно создана и запущена."
        ;;
    2)
        echo ""
        echo "Продолжаем без обновления конфигурации..."
        ;;
    esac
}

# Установка и минимальная конфигурация VOIP
install_voip_server() {
    os_select "Установить VOIP-сервер?" "Да" "Нет"
    case $? in
    1)
        os_select "Выберите действие" "Asterisk"
        case $? in
        1)
            echo ""
            echo "Проверка и установка зависимостей для Asterisk..."
            os_install "epel-release" "chkconfig" "libedit-devel"

            echo ""
            echo "Загружаем исходники..."
            wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz

            echo ""
            echo "Распаковка архива..."
            tar zxvf asterisk-22-current.tar.gz

            echo ""
            echo "Удаление архива..."
            rm -rf asterisk-22-current.tar.gz

            cd asterisk-22*/

            echo ""
            echo "Установка необходимых зависимостей..."
            contrib/scripts/install_prereq install

            echo ""
            echo "Настройка системы..."
            ./configure --libdir=/usr/lib64 --with-pjproject-bundled --with-jansson-bundled

            make

            make install

            make samples

            mkdir /etc/asterisk/samples

            mv /etc/asterisk/*.* /etc/asterisk/samples/

            make basic-pbx

            echo ""
            echo "Добавляем содержимое..."
            cp "$SE_SOURCE/tmp/etc/systemd/system/asterisk.service" /usr/lib/systemd/system/asterisk.service

            echo ""
            echo "Конфигурация Asterisk.Создание пользовательских конфигурационных файлов..."

            touch "/etc/asterisk/pjsip_custom.conf"

            touch "/etc/asterisk/extensions_custom.conf"

            echo "#include pjsip_custom.conf" >>"/etc/asterisk/pjsip.conf"

            echo "#include extensions_custom.conf" >>"/etc/asterisk/extensions.conf"

            sed -i "s^enabled =.*^enabled = yes^" /etc/asterisk/manager.conf

            echo ""
            echo "Добавление AMI пользователя"

            echo "[admin]" >>/etc/asterisk/manager.conf
            echo "secret = $SE_PASS_AMI" >>/etc/asterisk/manager.conf
            echo "read = all" >>/etc/asterisk/manager.conf
            echo "write = all" >>/etc/asterisk/manager.conf

            echo ""
            echo "Конфигурация AMI добавлена в manager.conf."

            echo ""
            echo "*------------------------------------------------------*"
            echo ""
            echo "Пароль пользователя AMI: \e[38;5;111m$SE_PASS_AMI\e[0m"
            echo ""
            echo "*------------------------------------------------------*"

            echo ""
            echo "Asterisk установлен. Запускаю службы..."
            systemctl enable asterisk.service

            systemctl start asterisk

            echo ""
            echo "Конфигурация Asterisk завершена."
            ;;
        esac
        ;;
    2)
        echo ""
        echo "Продолжаем без видео-сервера..."
        ;;
    esac
}

# Установка видео-сервера
install_hls_server() {
    os_select "Установить видео-сервер?" "Да" "Нет"
    case $? in
    1)
        yum groupinstall -y "Development Tools"

        echo ""
        echo "Загружаем исходники..."
        wget https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz

        tar -xvf ffmpeg-7.1.tar.xz

        cd ffmpeg-7.1

        echo ""
        echo "Конфигурируем ffmpeg..."
        ./configure --disable-x86asm

        make

        echo ""
        echo "Устанавливаем..."
        sudo make install
        ;;
    2)
        echo ""
        echo "Продолжаем без видео-сервера..."
        ;;
    esac
}

# Основной сценарий
main() {
    # Запрос на обновление системных компонентов
    os_update

    # Применение изменений
    setenforce 0

    sudo systemctl start firewalld
    sudo systemctl enable firewalld

    # Запрос на установку и минимальную конфигурацию веб-сервера
    install_http_server

    # Запрос на установку и минимальную конфигурацию СУБД
    install_database_service

    # Запрос на минимальную конфигурацию бэкенд сервера
    setup_backend_server

    # Запрос на установку и минимальную конфигурацию VOIP
    install_voip_server

    # Запрос на установку видео-сервера
    install_hls_server

    echo ""
    echo "Установка завершена."
}

# Обработка сигналов для корректного завершения
trap 'echo "Процесс установки остановлен пользователем."; exit 1' SIGINT SIGTERM

main
