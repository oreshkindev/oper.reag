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
if [ ! -f /etc/redhat-release ]; then
    echo "Неподдерживаемая операционная система."
    exit 1
fi

#
#
SE_PASS_AMI=""
#
#
SE_PASS_POSTGRES=""
#
#
SE_HTTP=""
#
#
SE_HOST=$(hostname -I | awk '{print $1}')
#
#
SE_SOURCE="/opt/oper.reag"

install_packages() {
    local PACKAGES=("$@")

    for P in "${PACKAGES[@]}"; do
        if ! rpm -q "$P" >/dev/null 2>&1; then

            yum install -y "$P"

            if [ $? -ne 0 ]; then
                print "Не удалось установить $P."
                exit 1
            fi
        else
            print "$P уже установлен."
        fi
    done
}

install_migrations() {
    for M in /opt/oper.reag/backend/migrations/*.sql; do
        sudo -u postgres psql -d postgres -f "$M"

        if [ $? -ne 0 ]; then
            print "Ошибка при выполнении миграции $M."
            exit 1
        fi
    done
}

install_postgresql() {
    install_packages "https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm"

    yum -qy module disable postgresql

    local PACKAGES=(
        "postgresql16-server"
        "postgresql16"
    )

    install_packages "${PACKAGES[@]}"
}

configure_postgresql() {
    postgresql-16-setup initdb

    systemctl enable postgresql-16.service --now

    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/16/data/postgresql.conf

    echo "host    all             all             127.0.0.1/32            md5" >>/var/lib/pgsql/16/data/pg_hba.conf

    SE_PASS_POSTGRES=$(openssl rand -base64 12)

    sudo -u postgres psql -c "ALTER USER postgres WITH ENCRYPTED PASSWORD '$SE_PASS_POSTGRES';"

    sed -i "s|export DATABASE_URL=.*|export DATABASE_URL=\"postgres://postgres:$SE_PASS_POSTGRES@localhost:5432/postgres?sslmode=disable\"|" $SE_SOURCE/backend/env.sh

    sudo firewall-cmd --permanent --add-port=5432/tcp
    sudo firewall-cmd --reload

    systemctl restart postgresql-16.service
}

configure_apache() {
    touch /etc/httpd/conf.d/frontend.conf

    cat $SE_SOURCE/tmp/etc/httpd/conf.d/frontend.conf >/etc/httpd/conf.d/frontend.conf

    apachectl configtest

    if [ $? -eq 0 ]; then
        systemctl restart httpd
    else
        print "Ошибка в конфигурации apache. Пожалуйста, проверьте файл /etc/httpd/conf.d/frontend.conf"
    fi

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
}

configure_nginx() {
    touch /etc/nginx/conf.d/frontend.conf

    cat $SE_SOURCE/tmp/etc/nginx/conf.d/frontend.conf >/etc/nginx/conf.d/frontend.conf

    nginx -t

    if [ $? -eq 0 ]; then
        systemctl restart nginx
    else
        print "Ошибка в конфигурации nginx. Пожалуйста, проверьте файл /etc/nginx/conf.d/frontend.conf"
    fi

    sudo firewall-cmd --permanent --add-service=http
    sudo firewall-cmd --reload
}

configure_backend_service() {
    touch /etc/systemd/system/backend.service

    cat $SE_SOURCE/tmp/etc/systemd/system/backend.service >/etc/systemd/system/backend.service

    chmod +x $SE_SOURCE/backend/env.sh
    chmod +x $SE_SOURCE/backend/bin/backend

    systemctl daemon-reload

    systemctl enable backend.service --now

    if [ "$SE_HTTP" = "n" ]; then
        PROXY_PASS=$(cat "$SE_SOURCE/tmp/etc/nginx/conf.d/proxy_backend.conf")
        sed -i "/}/i $PROXY_PASS" "/etc/nginx/conf.d/frontend.conf"
    else
        PROXY_PASS=$(cat "$SE_SOURCE/tmp/etc/httpd/conf.d/proxy_backend.conf")
        sed -i "/<\/VirtualHost>/i $PROXY_PASS" "/etc/httpd/conf.d/frontend.conf"
    fi
}

configure_backend_ami_service() {
    touch /etc/systemd/system/backend-ami.service

    cat $SE_SOURCE/tmp/etc/systemd/system/backend-ami.service >/etc/systemd/system/backend-ami.service

    chmod +x $SE_SOURCE/backend-ami/env.sh
    chmod +x $SE_SOURCE/backend-ami/bin/backend-ami

    systemctl daemon-reload

    systemctl enable backend-ami.service --now

    if [ "$SE_HTTP" = "n" ]; then
        PROXY_PASS=$(cat "$SE_SOURCE/tmp/etc/nginx/conf.d/proxy_backend-ami.conf")
        sed -i "/}/i $PROXY_PASS" "/etc/nginx/conf.d/frontend.conf"
    else
        PROXY_PASS=$(cat "$SE_SOURCE/tmp/etc/httpd/conf.d/proxy_backend-ami.conf")
        sed -i "/<\/VirtualHost>/i $PROXY_PASS" "/etc/httpd/conf.d/frontend.conf"
    fi
}

install_asterisk() {
    local PACKAGES=(
        "epel-release"
        "chkconfig"
        "libedit-devel"
    )

    install_packages "${PACKAGES[@]}"

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

    cat $SE_SOURCE/tmp/etc/systemd/system/asterisk.service >/usr/lib/systemd/system/asterisk.service

    DIR="/etc/asterisk"

    touch "/etc/asterisk/pjsip_custom.conf"

    touch "/etc/asterisk/extensions_custom.conf"

    echo "#include pjsip_custom.conf" >>"/etc/asterisk/pjsip.conf"

    echo "#include extensions_custom.conf" >>"/etc/asterisk/extensions.conf"

    SE_PASS_AMI=$(openssl rand -base64 16)

    sed -i 's/^;enabled = no/enabled = yes/' "/etc/asterisk/manager.conf"

    cat $SE_SOURCE/tmp/asterisk/manager.conf >/etc/asterisk/manager.conf

    sed -i 's/^secret = secret/secret = '$SE_PASS_AMI'/' "/etc/asterisk/manager.conf"

    sed -i "s|export SECRET=.*|export SECRET=\"$SE_PASS_AMI\"|" $SE_SOURCE/backend-ami/env.sh

    systemctl enable asterisk.service

    systemctl start asterisk
}

install_ffmpeg() {
    wget https://ffmpeg.org/releases/ffmpeg-7.1.tar.xz

    tar -xvf ffmpeg-7.1.tar.xz

    cd ffmpeg-7.1

    ./configure --disable-x86asm

    make

    sudo make install
}

# Основная логика
main() {
    yum check-update

    install_packages "nginx"

    configure_nginx

    install_asterisk

    install_postgresql

    configure_postgresql

    install_ffmpeg

    configure_backend_service

    configure_backend_ami_service

    install_migrations

    systemctl daemon-reload

    systemctl restart backend.service

    systemctl restart backend-ami.service

    systemctl restart asterisk.service

    systemctl restart nginx

    cd

    print "Установка завершена."
    print "*------------------------------------------------------*"
    print "Пароль пользователя postgres: $SE_PASS_POSTGRES"
    print "*------------------------------------------------------*"
    print "Пароль пользователя AMI: $SE_PASS_AMI"
    print "*------------------------------------------------------*"
    print "Интерфейс доступен по адресу: http://$SE_HOST/"
    print "*------------------------------------------------------*"
}

main
