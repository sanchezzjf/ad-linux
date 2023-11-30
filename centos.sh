#!/bin/bash

# Testa se o usuário que está tentando rodar o script tem permissão de root
if [ "$EUID" -ne 0 ]
	then echo "Por favor rodar como root"
	exit
fi

# Atualiza o sistema e instala os pacotes necessários
yum update -y
yum install sssd realmd oddjob oddjob-mkhomedir adcli samba-common samba-common-tools krb5-workstation openldap-clients policycoreutils-python -y

read -p "Digite o domínio que deseja ingressar: " domain

#Coloca o dominio em CAPS
domain_caps=$(echo $domain | tr '[:lower:]' '[:upper:]')
#Coloca o hostname em CAPS
hostname_caps=$(echo $HOSTNAME | tr '[:lower:]' '[:upper:]')

IP4=$(hostname -I | cut -f1 -d ' ')
# Testa se a alteração já foi feita caso o script precise ser rodado mais de uma vez
if ! [ grep -Fq "$IP4" /etc/hosts ]
then
# Pega o IP da máquina e adiciona ao arquivo de hosts para formar o FQDN
	echo "$IP4 $hostname_caps.$domain $hostname_caps" >> /etc/hosts
fi

# Cria um backup do arquivo de configuração do Kerberos
cp /etc/krb5.conf /etc/krb5.conf.bkp

# Reescreve o arquivo de configuração do Kerberos com o necessário
cat > /etc/krb5.conf << EOL
includedir /etc/krb5.conf.d/

[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 dns_lookup_kdc = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 pkinit_anchors = FILE:/etc/pki/tls/certs/ca-bundle.crt
 default_realm = AD-AUTH.LIFE.COM.BR
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
 AD-AUTH.LIFE.COM.BR = {
  kdc = ad-auth.life.com.br
  admin_server = kerberos.example.com
 }

[domain_realm]
 .ad-auth.life.com.br = AD-AUTH.LIFE.COM.BR
EOL


# Procura o domínio desejado
realm -v discover $domain

read -p "Digite o usuário adm do AD: " ad_admin_user

# Insere a máquina no domínio com o usuário previamente fornecido
realm -v join $domain -U $ad_admin_user

# Altera a configuração padrão da criação do diretório dos usuários do AD
sed -i 's+fallback_homedir = /home/%u@%d+fallback_homedir = /home/%d/%u+g' /etc/sssd/sssd.conf
sed -i 's/use_fully_qualified_names = True/use_fully_qualified_names = False/' /etc/sssd/sssd.conf

systemctl restart sssd

echo "Configuração finalizada"

exit
