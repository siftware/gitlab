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
external_url 'http://${DOMAIN}'
gitlab_rails['smtp_enable'] = true
gitlab_rails['gitlab_email_enabled'] = true
gitlab_rails['gitlab_email_from'] = 'gitlab@${DOMAIN}'
" > /etc/gitlab/gitlab.rb

gitlab-ctl reconfigure

