#!/bin/bash
debconf-set-selections <<< "postfix postfix/mailname string ${DOMAIN}"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

apt-get update
apt-get install ca-certificates curl postfix letsencrypt

ufw allow OpenSSH
ufw allow http
ufw allow https
ufw enable

curl -LO https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh
bash script.deb.sh

apt-get update
apt-get install gitlab-ce
rm script.deb.sh

gitlab-ctl reconfigure

