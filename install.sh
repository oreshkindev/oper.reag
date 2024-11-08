#!/usr/bin/env bash

if [ "$(id -u)" -ne 0 ]; then
    echo "Необходимы права root для запуска сценария."
    exit 1
fi

if [ ! -f /etc/redhat-release ]; then
    echo "Неподдерживаемая операционная система."
    exit 1
fi

PASS_AMI=$(openssl rand -base64 12)

PASS_POSTGRES=$(openssl rand -base64 12)

SOURCE_PATH="/opt/oper.reag"

HOST=$(hostname -I | awk '{print $1}')

HTTP=""

install_packages() {

    local PACKAGES=("$@")

    for P in "${PACKAGES[@]}"; do
        if ! rpm -q "$P" >/dev/null 2>&1; then
            echo ""
            echo "Пакет $P не найден среди установленных. Ищем в репозитории..."

            SEARCH_RESULTS=$(yum search "$P" 2>/dev/null)

            if echo "$SEARCH_RESULTS" | grep -q "No matches found"; then
                echo "Пакет $P не найден в репозитории."
                echo "Доступные пакеты в репозитории:"
                echo "$SEARCH_RESULTS"

                echo ""
                echo -n "Введите имя пакета для установки или оставьте пустым, чтобы пропустить: "
                read -r CUSTOM_PACKAGE

                if [ -n "$CUSTOM_PACKAGE" ]; then
                    echo "Устанавливаем $CUSTOM_PACKAGE..."
                    yum install -y "$CUSTOM_PACKAGE"
                    if [ $? -ne 0 ]; then
                        echo ""
                        echo "Не удалось установить $CUSTOM_PACKAGE. Проверьте подключение к интернету и повторите попытку."
                        exit 1
                    fi
                else
                    echo ""
                    echo "$P пропущен."
                fi
            else
                echo "Пакет $P найден в репозитории. Устанавливаем..."
                yum install -y "$P"
                if [ $? -ne 0 ]; then
                    echo ""
                    echo "Не удалось установить $P. Проверьте подключение к интернету и повторите попытку."
                    exit 1
                fi
            fi
        else
            echo ""
            echo "$P уже установлен."
        fi
    done
}

configure_apache() {

    echo "Настройка конфигурации apache..."
    echo ""
    touch /etc/httpd/conf.d/frontend.conf

    envsubst <$SOURCE_PATH/tmp/etc/httpd/conf.d/frontend.conf >/etc/httpd/conf.d/frontend.conf

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
    echo "Интерфейс доступен по адресу: http://$HOST/"
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

    envsubst <$SOURCE_PATH/tmp/etc/nginx/conf.d/frontend.conf >/etc/nginx/conf.d/frontend.conf

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
    echo "Интерфейс доступен по адресу: http://$HOST/"
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

    if [ "$HTTP" = "nginx" ]; then
        PROXY=$(cat "$SOURCE_PATH/tmp/etc/nginx/conf.d/proxy_backend.conf")
        printf '%s\n' "$PROXY" | sed -i "/}/r /dev/stdin" "/etc/nginx/conf.d/frontend.conf"

    elif [ "$HTTP" = "apache" ]; then
        PROXY=$(cat "$SOURCE_PATH/tmp/etc/httpd/conf.d/proxy_backend.conf")
        printf '%s\n' "$PROXY" | sed -i "/<\/VirtualHost>/r /dev/stdin" "/etc/httpd/conf.d/frontend.conf"
    else
        echo ""
        echo "Веб сервер неопределен..."
        exit 1
    fi

    echo "Служба backend.service успешно создана и запущена."
    echo ""
}

main() {

    #
    #
    echo ""
    echo "Обновить системные компоненты перед установкой (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    1 | "Да" | "да" | "д")
        yum check-update
        ;;
    *)
        echo ""
        echo "Продолжаем без обновления системных компонентов..."
        ;;
    esac

    #
    #
    echo ""
    echo "Установить веб-сервер (да / нет)? (рекомендуется):"
    read -r R

    case "$R" in
    1 | "Да" | "да" | "д")
        echo ""
        echo "Какой веб-сервер установить (apache / nginx)?:"
        read -r R

        case "$R" in
        1 | "apache" | "a")
            HTTP="apache"
            install_packages "httpd"

            echo ""
            echo "Произвести первоначальную настройку apache (да / нет)? (рекомендуется):"
            read -r R

            case "$R" in
            1 | "Да" | "да" | "д")
                configure_apache
                ;;
            *)
                echo ""
                echo "После установки произведите настройку apache"
                ;;
            esac
            ;;
        2 | "nginx" | "n")
            HTTP="nginx"
            install_packages "nginx"

            echo ""
            echo "Произвести первоначальную настройку nginx (да / нет)? (рекомендуется):"
            read -r R

            case "$R" in
            1 | "Да" | "да" | "д")
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
        echo "Настройте веб сервер на свое усмотрение. Скомпилированные исходники будут расположены в $SOURCE_PATH/frontend/"
        ;;
    esac

    echo ""
    echo "Настройка бэкенда..."
    configure_backend_service
}

main
