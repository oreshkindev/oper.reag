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

# Основной сценарий
main() {
    # Запрос на обновление системных компонентов
    os_update

    # Запрос на установку и минимальную конфигурацию веб-сервера
    install_http_server
}

# Обработка сигналов для корректного завершения
trap 'echo "Процесс установки остановлен пользователем."; exit 1' SIGINT SIGTERM

main
