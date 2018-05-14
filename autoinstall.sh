#!bin/bash
#Configurador e instalador de NagiosPi - Cacti - Postfix#
echo "Configurador de NagiosPi"
echo "Recuerde ejecutar este script con sudo bash, si no es así, presione control + c"
read -r -p "¿Desea configurar NagiosPi? (s/n): " nagiospi_conf
if [ $nagiospi_conf = "s" ] || [ $nagiospi_conf = "S" ];
	then
		echo "Comenzando..."
	else
		echo "Saliendo..."
		exit 0
fi

read -r -p "¿Configurar dirección Ip? (s/n): " network_conf
if [ $network_conf = "s" ] || [ $network_conf = "S" ];
	then
		read -r -p "Introduzca la dirección Ip : " network_address
		read -r -p "Introduzca la máscara de red : " netmask
		read -r -p "Introduzca la puerta de enlace : " gateway
		sed -i "/iface eth0 inet dhcp/d" /etc/network/interfaces
		echo "iface eth0 inet static" >> /etc/network/interfaces
		echo "address $network_address" >> /etc/network/interfaces
		echo "netmask $netmask" >> /etc/network/interfaces
		echo "gateway $gateway" >> /etc/network/interfaces
		sudo service networking restart
		sudo ifup eth0
fi

read -r -p "¿Configurar DNS? (s/n): " dns_conf
if [ $dns_conf = "s" ]  || [ $dns_conf = "S" ];
	then
		sed -i "/nameserver/d" /etc/resolv.conf
		read -r -p "¿Configurar DNS de forma predeterminada? (s/n): " dns_conf_default
		if [ $dns_conf_default = "s" ] || [ $dns_conf_default = "S" ];
			then
				echo "nameserver 8.8.8.8" >> /etc/resolv.conf
			else
				read -r -p "Introduzca la dirección DNS: " dns_conf_manually
				echo "nameserver $dns_conf_manually" >> /etc/resolv.conf
		fi
fi
read -r -p "¿Instalar Postfix? (s/n): " postfix_install
if [ $postfix_install = "s" ] || [ $postfix_install = "S" ];
	then
		sudo apt-get update
		sudo apt-get install postfix
fi

read -r -p "¿Configurar Postfix? (s/n): " postfix_conf
if [ $postfix_conf = "s" ] || [ $postfix_conf = "S" ];
	then
		sudo sed -i "s/relayhost =/relayhost = [smtp.gmail.com]:587/g" "/etc/postfix/main.cf"
		echo "smtpd_tls_security_level = encrypt" >> /etc/postfix/main.cf
		echo "smtp_sasl_auth_enable = yes" >> /etc/postfix/main.cf
		echo "smtp_sasl_security_options =" >> /etc/postfix/main.cf
		echo "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd" >> /etc/postfix/main.cf
		echo "smtp_use_tls = yes" >> /etc/postfix/main.cf
		echo "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt" >> /etc/postfix/main.cf
		read -r -p "¿Configurar postfix de manera predeterminada? (s/n): " postfix_conf_default
			if [ $postfix_conf_default = "s" ] || [ $postfix_conf_default = "S" ];
				then
					echo "[smtp.gmail.com]:587 ntnagios@gmail.com:ntnagios123" >> /etc/postfix/sasl_passwd
			elif [ $postfix_conf_default = "n" ] || [ $postfix_conf_default = "N" ];
				then
					read -r -p "Introduzca dirección de correo electrónico gmail para las notificaciones : " notifications_mail
					read -r -p "Introduzca contraseña del correo electrónico gmail : " notifications_passwd
					sudo echo "[smtp.gmail.com]:587 $notifications_mail:$notifications_passwd" >> /etc/postfix/sasl_passwd
			fi
		sudo postmap /etc/postfix/sasl_passwd
		sudo service postfix restart
		sudo service apache2 restart
fi

read -r -p "¿Instalar cacti? (s/n): " cacti_install
if [ $cacti_install = "s" ] || [ $cacti_install = "S" ];
	then
		tar -zxvf cacti-1.1.37.tar.gz
		sudo mv cacti-1.1.37 cacti
		sudo mv cacti /var/www/
		mysql_root_passwd=nagiosadmin
		sudo mysqladmin --user=root -p$mysql_root_passwd create cacti
		sudo mysql --user=root -p$mysql_root_passwd cacti < /var/www/cacti/cacti.sql
		read -r -p "¿Desea cambiar la contraseña del root de mysql? (s/n): " mysql_root_change
			if [ $mysql_root_change = "s" ];
				then
					read -r -p "Introduzca la nueva contraseña de root de mysql: " mysql_root_passwd
					sudo mysql -uroot -pnagiosadmin -e "GRANT ALL ON cacti.* TO root@localhost IDENTIFIED BY '$mysql_root_passwd'; flush privileges;"
			fi
		read -r -p "¿Desea cambiar la contraseña del usuario para cacti? (s/n): " mysql_cacti_user_change
			if [ $mysql_cacti_user_change = "s" ] || [ $mysql_cacti_user_change = "S" ];
				then
					read -r -p "Introduzca la nueva contraseña para el usuario cacti de mysql: " cactiuser_passwd
					sudo mysql -uroot -p$mysql_root_passwd -e "GRANT ALL ON cacti.* TO cactiuser@localhost IDENTIFIED BY '$cactiuser_passwd'; flush privileges;"
					sed -i "s/database_password = 'cactiuser'/database_password = '$cactiuser_passwd'/g" "/www/var/cacti/include/config.php"
			else
					sudo mysql -uroot -p$mysql_root_passwd -e "GRANT ALL ON cacti.* TO cactiuser@localhost IDENTIFIED BY 'cactiuser'; flush privileges;"
			fi
		sudo chown -R www-data /www/var/cacti/rra 
		sudo chown -R www-data /www/var/cacti/log
		sudo echo "*/5**** www-data php /var/www/cacti/poller.php > /dev/null 2>&1" >> /etc/crontab
		sudo service apache2 restart
		sudo service mysql restart
		sudo apt-get install php5-ldap
		sudo mysql -uroot -p$mysql_root_passwd -e "use mysql; insert into time_zone_name values ('Europe/Spain','1'); GRANT SELECT ON mysql.time_zone_name TO cactiuser@localhost; flush privileges;"
		sudo echo "date.timezone = 'Europe/Spain'" >> /etc/php5/apache2/php.ini
		sudo service apache2 restart
		sudo chmod -R 777 /var/www/cacti/
		sudo apt-get install rrdtool		
fi

read -r -p "¿Desea cambiar la contraseña de la página web de nagios? (s/n): " nagios_passwd_change
if [ $nagios_passwd_change = "s" ] || [ $nagios_passwd_change = "S" ];
	then
		sudo htpasswd -c /etc/nagios3/htpasswd.users nagiosadmin
		sudo service apache2 restart
fi

read -r -p "¿Desea cambiar la contraseña de la página web de nconf? (s/n): " nconf_passwd_change
if [ $nagios_passwd_change = "s" ] || [ $nagios_passwd_change = "S" ];
	then
		sudo echo "<Directory /var/www/nconf/>" >> /etc/nagios3/apache2.conf
		sudo echo "Options FollowSymLinks" >> /etc/nagios3/apache2.conf
		sudo echo "AllowOverride AuthConfig" >> /etc/nagios3/apache2.conf
		sudo echo "AuthName 'Nagios Access'" >> /etc/nagios3/apache2.conf
		sudo echo "AuthType Basic" >> /etc/nagios3/apache2.conf
		sudo echo "AuthUserFile /var/www/nconf/htpasswd.users" >> /etc/nagios3/apache2.conf
		sudo echo "Require valid-user" >> /etc/nagios3/apache2.conf
		sudo echo "</Directory>" >> /etc/nagios3/apache2.conf
		sudo cp /etc/nagios3/htpasswd.users /var/www/nconf/
		read -r -p "Introduzca el nombre del nuevo usuario para Nconf: " nconf_user_new
		sudo htpasswd -c /var/www/nconf/htpasswd.users $nconf_user_new
		sudo service apache2 restart
fi

read -r -p "¿Desea borrar las contraseñas que se muestran en la página principal? (s/n): " nagios_delete_passwords
if [ $nagios_delete_passwords = "s" ] || [ $nagios_delete_passwords = "S" ];
	then
		sudo sed -i "s/nagiosadmin)//g" "/var/www/index.html"
		sudo sed -i "s/(nagiosadmin//g" "/var/www/index.html"
		sudo sed -i "s/(nconf//g" "/var/www/index.html"
		sudo sed -i "s/(admin//g" "/var/www/index.html"
		sudo sed -i "s/admin)//g" "/var/www/index.html"
		sudo sed -i "s/(root//g" "/var/www/index.html"
		sudo sed -i "s/nagiosadmin)//g" "/var/www/index.html" 
fi		

read -r -p "¿Desea copiar las contraseñas en algún fichero? (s/n): " nagios_save_passwords
	if [ $nagios_save_passwords = "s" ] || [ $nagios_save_passwords = "S" ];
		then
			read -r -p "Indique el nombre del fichero (en caso de no existir se creará): " nagios_file_saving
				while [ -z $nagios_file_saving ];
					do							
						echo "No se ha escrito ningún nombre"
						read -r -p "Indique el nombre del fichero (en caso de no existir se creará): " nagios_file_saving
					done
				sudo echo -e "\n Nagios: (nagiosadmin/nagiosadmin) \n Nconf: (nconf/nagiosadmin) \n Nagvis: (admin/admin) \n PHPmyadmin: (root/nagiosadmin) \n Raspcontrol (admin/nagiosadmin)" > $nagios_file_saving
	fi					
		

read -r -p "¿Desea cambiar la fecha y hora del sistema? (s/n): " time_set
if [ $time_set = "s" ] || [ $time_set = "S" ];
	then
		read -r -p "Introduzca la fecha actual con el formato año-mes-día: " year_month_day
		read -r -p "Introduzca la hora actual con el formato horas:minutos:segundos: " hours_minutes_seconds
		sudo date --set "$year_month_day $hours_minutes_seconds"
fi

read -r -p "¿Desea cambiar la contraseña del root del sistema? (s/n): " system_root_change
if [ $system_root_change = "s" ] || [ $system_root_change = "S" ];
	then
		passwd
fi
 
   

