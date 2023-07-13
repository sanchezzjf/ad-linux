#!/bin/bash

# Testa se o usuário que está tentando rodar o script tem permissão de root
if [ "$EUID" -ne 0 ]
	then echo "Por favor rodar como root"
	exit
fi

# Atualiza o sistema e instala os pacotes necessários
apt update -y
apt install -y sssd-ad sssd-tools realmd adcli libnss-sss libpam-sss samba-common-bin krb5-config

read -p "Digite o domínio que deseja ingressar: " domain

domain_caps=$(echo $domain | tr '[:lower:]' '[:upper:]')
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
[libdefaults]
	default_realm = ${domain_caps}
        kdc_timesync = 1
        ccache_type = 4
        forwardable = true
        proxiable = true
        fcc-mit-ticketflags = true
        rdns = false
[realms]
        ${domain_caps} = {
                admin_server = ${domain}
                default_domain = ${domain}
        }
[domain_realm]
        .${domain} = ${domain_caps}
EOL

# Procura o domínio desejado
realm -v discover $domain

read -p "Digite o usuário adm do AD: " ad_admin_user

# Insere a máquina no domínio com o usuário previamente fornecido
realm -v join $domain -U $ad_admin_user

# Habilita a criação de diretórios ao logar
pam-auth-update --enable mkhomedir

# Altera a configuração padrão da criação do diretório dos usuários do AD
sed -i 's+fallback_homedir = /home/%u@%d+fallback_homedir = /home/%d/%u+g' /etc/sssd/sssd.conf
systemctl restart sssd

echo "Configuração finalizada"

exit
