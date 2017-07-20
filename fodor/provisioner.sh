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


mkdir -p /var/www/letsencrypt
chmod -R a+wr /var/www/letsencrypt

echo "external_url 'http://${DOMAIN}'
gitlab_rails['smtp_enable'] = true
gitlab_rails['gitlab_email_enabled'] = true
gitlab_rails['gitlab_email_from'] = 'gitlab@${DOMAIN}'
gitlab_rails['backup_keep_time'] = 604800
gitlab_rails['smtp_enable_starttls_auto'] = false
nginx['custom_gitlab_server_config'] = 'location ^~ /.well-known { root /var/www/letsencrypt; }'
" > /etc/gitlab/gitlab.rb

gitlab-ctl reconfigure


# SSL
letsencrypt certonly -a webroot -w /var/www/letsencrypt -d ${DOMAIN} --agree-tos --email ${ADMIN_EMAIL}

sed -i -e "s/external_url.*/external_url 'https:\/\/${DOMAIN}'/g" /etc/gitlab/gitlab.rb

echo "
nginx['ssl_certificate'] = '/etc/letsencrypt/live/${DOMAIN}/fullchain.pem'
nginx['ssl_certificate_key'] = '/etc/letsencrypt/live/${DOMAIN}/privkey.pem'
" >> /etc/gitlab/gitlab.rb

gitlab-ctl reconfigure


echo "
0 0 */3 * * root /usr/bin/letsencrypt renew >> /var/log/le-renew.log
10 0 */3 * * root /usr/bin/gitlab-ctl restart nginx
" > /etc/cron.d/letsencrypt

chmod 644 /etc/cron.d/letsencrypt

echo "APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Download-Upgradeable-Packages \"1\";
APT::Periodic::AutocleanInterval \"1\";
APT::Periodic::Unattended-Upgrade \"1\";" > /etc/apt/apt.conf.d/10periodic

echo "Unattended-Upgrade::Allowed-Origins {
    \"${distro_id}:${distro_codename}-security\";
    \"*packages.gitlab.com/gitlab/gitlab-ce:${distro_codename}\";
};

Unattended-Upgrade::Package-Blacklist {
    //
};

Unattended-Upgrade::Mail \"${ADMIN_EMAIL}\";
" >  /etc/apt/apt.conf.d/50unattended-upgrades


echo "0 2 * * * root /opt/gitlab/bin/gitlab-rake gitlab:backup:create CRON=1
" > /etc/cron.d/gitlab_backup

/etc/init.d/cron restart
