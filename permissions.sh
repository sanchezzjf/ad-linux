#!/bin/bash

# Testa se o usuário que está tentando rodar o script tem permissão de root
if [ "$EUID" -ne 0 ]
	then echo "Por favor rodar como root"
	exit
fi
read -p "Digite o domínio que a máquina está inserida: " domain

echo "Fazendo backup do arquivo de sudoers..."

cp /etc/sudoers /etc/sudoers.bkp

echo "Editando o arquivo de sudoers..."

cp /etc/sudoers /tmp/sudoers.tmp

cat << EOF >> /tmp/sudoers.tmp

#Alias de comandos
Cmnd_Alias NOROOT = !/usr/bin/su, !/bin/bash
Cmnd_Alias VIEW_IPTABLES= /usr/sbin/iptables -L, /usr/sbin/iptables -nL

#Grupos definidos no AD
%life_administradores@$domain	    ALL=(ALL) ALL, NOROOT
%life_operador@$domain		    ALL=(ALL) ALL, NOROOT, !/sbin/shutdown, !/sbin/reboot, !/usr/bin/rm
%life_viewer@$domain		    ALL=(ALL) /usr/bin/cat, VIEW_IPTABLES

EOF

mv -f /tmp/sudoers.tmp /etc/sudoers

echo "Finalizado configuração"



