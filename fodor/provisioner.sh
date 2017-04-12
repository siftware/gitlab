#!/bin/bash
debconf-set-selections <<< "postfix postfix/mailname string ${DOMAIN}"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

apt-get update
apt-get -y install ca-certificates curl postfix letsencrypt

ufw allow OpenSSH
ufw allow http
ufw allow https
yes | ufw enable

curl -LO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh
bash script.deb.sh

apt-get -y install gitlab-ce
rm script.deb.sh


echo "
external_url 'https://${DOMAIN}'
gitlab_rails['smtp_enable'] = true
gitlab_rails['gitlab_email_enabled'] = true
gitlab_rails['gitlab_email_from'] = 'gitlab@${DOMAIN}'
gitlab_rails['smtp_enable_starttls_auto'] = false
nginx['custom_gitlab_server_config'] = "location ^~ /.well-known { root /var/www/letsencrypt; }"
" > /etc/gitlab/gitlab.rb

gitlab-ctl reconfigure


# SSL
mkdir -p /var/www/letsencrypt
letsencrypt certonly -a webroot -w /var/www/letsencrypt -d ${DOMAIN} --agree-tos --email ${ADMIN_EMAIL}

echo "
nginx['ssl_certificate'] = "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
nginx['ssl_certificate_key'] = "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
" >> /etc/gitlab/gitlab.rb

gitlab-ctl reconfigure
