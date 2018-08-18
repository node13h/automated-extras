#!/usr/bin/env bash

# MIT license
# Copyright 2017 Sergej Alikov <sergej.alikov@gmail.com>


nginx_vendor_repo () {
    cat <<"EOF"
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=0
enabled=1
EOF
}


setup_vendor_nginx_repository () {
    msg "Setting up vendor Nginx repository"

    nginx_vendor_repo | to_file /etc/yum.repos.d/nginx.repo
}

setup_certbot_environment () {
    local certbot_home="${1}"
    local certbot_webroot="${2}"

    # Protect from relabeling /
    [[ -n "${certbot_webroot}" ]] || throw "Empty certbot_webroot is not supported"

    msg "Setting up certbot environment"

    if ! user_exists certbot; then
        cmd useradd --system --home-dir "${certbot_home}" certbot
    fi

    cmd mkdir -p "${certbot_home}"
    cmd chown certbot:nginx "${certbot_home}"
    cmd chmod 750 "${certbot_home}"
    cmd mkdir -p "${certbot_webroot}"
    cmd chown certbot:nginx "${certbot_webroot}"
    cmd chmod 755 "${certbot_webroot}"
    cmd semanage fcontext -a -t httpd_sys_content_t "${certbot_webroot%/}(/.*)?"
    cmd restorecon -r "${certbot_webroot}"
    cmd semanage fcontext -a -t httpd_sys_content_t "${certbot_home%/}/conf/archive(/.*)?"
    cmd restorecon -r "${certbot_home}"
}


create_https_certificates () {
    local certbot_home="${1}"
    local certbot_webroot="${2}"
    local admin_email="${3}"
    local force_update="${4}"

    shift 4

    [[ "${#}" -gt 0 ]] || return 1

    local domain
    local -a args=()

    if ! [[ -e "${certbot_home}/conf/live/${1}/fullchain.pem" ]] || is_true "${force_update}"; then
        msg "Creating certificates/keys for ${*}"

        args=('-n'
              '--agree-tos'
              '--text'
              '-m' "${admin_email}"
              '--logs-dir' "${certbot_home}/logs"
              '--config-dir' "${certbot_home}/conf"
              '--work-dir' "${certbot_home}/work"
              '--webroot'
              '-w' "${certbot_webroot}"
             )

        if is_true "${force_update}"; then
            args+=('--expand')
        fi

        for domain in "${@}"; do
            args+=('-d' "${domain}")
        done

        cmd sudo -u certbot certbot certonly "${args[@]}"
    fi
}

certbot_timer () {
    cat <<"EOF"
[Unit]
Description=Weekly check for Let's Encrypt's certificates renewal

[Timer]
# The official documentation suggests running certbot two times per day but I
# find once a week to be reasonable.
OnCalendar=Sun *-*-* 04:00:00
# Use this line instead of you prefer running the check daily.
# OnCalendar=*-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

certbot_service () {
    local certbot_home="${1}"

    cat <<EOF
[Unit]
Description=Let's Encrypt certificate renewal

[Service]
Type=oneshot

User=certbot
Group=certbot
UMask=0027

PermissionsStartOnly=yes
ExecStart=/usr/bin/certbot renew -q --logs-dir $(quoted_for_systemd "${certbot_home}/logs") --config-dir $(quoted_for_systemd "${certbot_home}/conf") --work-dir $(quoted_for_systemd "${certbot_home}/work") --renew-hook 'date --iso=min > $(quoted "${certbot_home}/renewed")'
ExecStartPost=/usr/bin/systemctl start --no-block certbot-renewed

NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=yes
ProtectHome=yes

CapabilityBoundingSet=
AmbientCapabilities=
EOF
}

certbot_renewed_service () {
    local certbot_home="${1}"

    cat <<EOF
[Unit]
Description=Restart selected daemons when Let's Encrypt certificates are renewed
ConditionFileNotEmpty=${certbot_home}/renewed

[Service]
Type=oneshot

User=certbot
Group=certbot
UMask=0027

PermissionsStartOnly=yes
ExecStart=/usr/bin/rm -- $(quoted_for_systemd "${certbot_home}/renewed")
ExecStartPost=/usr/bin/systemctl restart --no-block nginx

NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=yes
ProtectHome=yes

CapabilityBoundingSet=
AmbientCapabilities=
EOF
}


site_default () {
    local certbot_webroot="${1}"

    cat <<EOF
server {
        listen 80 default_server;
        listen [::]:80 default_server ipv6only=on;

        root /usr/share/nginx/html;
        index index.html index.htm;

        server_name localhost;
	server_tokens off;

        location /.well-known/ {
                 root "${certbot_webroot}";
        }

        location / {
		return 302 https://\$host\$request_uri;
	}

	location /nginx_status {
		stub_status on;    # activate stub_status module
		access_log off;
		allow 127.0.0.1;   # restrict access to local only
		deny all;
	}
}
EOF
}
