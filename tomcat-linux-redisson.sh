#!/bin/bash

## Selecting Tomcat version
echo 'Please select Tomcat version:'
tomcat_versions=( 'v9.0.50' 'v9.0.52 ' 'v9.0.53' 'v9.0.54 ' 'v9.0.55 ' 'v9.0.56 ' 'v9.0.58' 'v9.0.59' 'v9.0.60' 'v9.0.62' 'v9.0.63' 'v9.0.64' )
t_version_count=0
for t in ${tomcat_versions[@]}; do
  echo "$t_version_count	$t"
  t_version_count=$((t_version_count+1))
done
t_version_count=$((t_version_count-1))
echo "Enter selected Tomcat version (default: $t_version_count):"
read -e user_selection
user_selected_version=${tomcat_versions[$user_selection]}
if [ -z "$user_selected_version" ]
then
	  user_selected_version=${tomcat_versions[$t_version_count]}
	  echo "Invalid value provided. Default version $user_selected_version is used."
else
	  echo "Selected Tomcat version: $user_selected_version"
fi
user_selected_version_a=$(echo "$user_selected_version" | cut -c2-50)

# Download Tomcat 9.0.58
echo "Downloading Tomcat $user_selected_version_a ..."
cd ~/Downloads
curl -L "https://archive.apache.org/dist/tomcat/tomcat-9/$user_selected_version/bin/apache-tomcat-$user_selected_version_a.zip" > "apache-tomcat-$user_selected_version_a.zip"
unzip -qq "apache-tomcat-$user_selected_version_a.zip"

echo 'Installing Tomcat'
## Move Tomcat to final location
mv "apache-tomcat-$user_selected_version_a" tomcat9x
sudo mkdir -p /usr/share
sudo rm -f -r /usr/share/tomcat9x
sudo mv ~/Downloads/tomcat9x /usr/share

# Download Redisson
# Redisson version
redisson_versions=('3.16.0' '3.16.1' '3.16.2' '3.16.3' '3.16.4' '3.16.5' '3.16.6' '3.16.7' '3.16.8' '3.17.0' '3.17.1' '3.17.2' '3.17.3' '3.17.4')
echo 'Please select Redisson version:'
r_version_count=0
for t in ${redisson_versions[@]}; do
  echo "$r_version_count	$t"
  r_version_count=$((r_version_count+1))
done
r_version_count=$((r_version_count-1))
echo "Enter selected Redisson version (default: $r_version_count):"
read -e user_selection_redisson
user_selected_redisson_version=${redisson_versions[$user_selection_redisson]}
if [ -z "$user_selected_redisson_version" ]
then
	user_selected_redisson_version=${redisson_versions[$r_version_count]}
	echo "Invalid value provided. Default version $user_selected_redisson_version is used."
else
	echo "Selected Redisson version: $user_selected_redisson_version"
fi
echo "Downloading Redisson $user_selected_redisson_version ..."
curl -L "https://repo1.maven.org/maven2/org/redisson/redisson-tomcat-9/$user_selected_redisson_version/redisson-tomcat-9-$user_selected_redisson_version.jar" > "redisson-tomcat-9-$user_selected_redisson_version.jar"
curl -L "https://repo1.maven.org/maven2/org/redisson/redisson-all/$user_selected_redisson_version/redisson-all-$user_selected_redisson_version.jar" > "redisson-all-$user_selected_redisson_version.jar"
mv ~/Downloads/{"redisson-all-$user_selected_redisson_version.jar","redisson-tomcat-9-$user_selected_redisson_version.jar"} /usr/share/tomcat9x/lib

sudo chown -R $USER /usr/share/tomcat9x
sudo chmod +x /usr/share/tomcat9x/bin/*.sh



## Create tomcat Native conf
echo 'Adding libnative to environment..'
mkdir /usr/share/tomcat9x/libnative
ln -s /usr/lib/x86_64-linux-gnu/libtcnative-1.a /usr/share/tomcat9x/libnative/libtcnative-1.a
ln -s /usr/lib/x86_64-linux-gnu/libtcnative-1.so /usr/share/tomcat9x/libnative/libtcnative-1.so
ln -s /usr/lib/x86_64-linux-gnu/libtcnative-1.so.0 /usr/share/tomcat9x/libnative/libtcnative-1.so.0
ln -s /usr/lib/x86_64-linux-gnu/libtcnative-1.so.0.2.31 /usr/share/tomcat9x/libnative/libtcnative-1.so.0.2.31
tomcat_native='#!/bin/sh'"\n"
tomcat_native+='# Set path to Tomcat Native.'"\n"
tomcat_native+='CATALINA_OPTS="$CATALINA_OPTS -Djava.library.path=/usr/share/tomcat9x/libnative"'
echo -e $tomcat_native > /usr/share/tomcat9x/bin/setenv.sh
chomd +x /usr/share/tomcat9x/bin/setenv.sh

echo 'Updating Tomcat configuration..'
## Create Redis conf
redis_conf='singleServerConfig:'"\n"
redis_conf+='  address: "redis://127.0.0.1:6379"'"\n"
redis_conf+='  database: 0'"\n"
echo -e $redis_conf > /usr/share/tomcat9x/conf/redisson.yaml

## Silence TLD flood
echo -e "\n"'org.apache.jasper.servlet.TldScanner.level = WARNING'"\n" >> /usr/share/tomcat9x/conf/logging.properties

## Add Redisson Session Manager
replace_a='<Context reloadable="true" crossContext="true" sessionCookiePath="\/">\n'
replace_a+='\n	<ResourceLink name="bean/redisson" global="bean/redisson" type="org.redisson.api.RedissonClient" \/>'
replace_a+='\n	<Manager className="org.redisson.tomcat.Jndibean/redissonionManager" readMode="REDIS" jndiName="bean/redisson" updateMode="AFTER_REQUEST" broadcastSessionEvents="true" broadcastSessionUpdates="true" keyPrefix="tms" \/>\n'
sed -i "s/<Context>/$replace_a/g" /usr/share/tomcat9x/conf/context.xml

## Add Redisson data source
replace_b='<GlobalNamingResources>\n\n'
replace_b+='		<Resource name="bean/redisson" auth="Container" factory="org.redisson.JndiRedissonFactory" configPath="${catalina.base}\/conf\/redisson.yaml" closeMethod="shutdown" \/>\n'
sed -i "s/<GlobalNamingResources>/$replace_b/g" /usr/share/tomcat9x/conf/server.xml

## Edit Tomcat users
tomcat_admin_psw='P'$(date | md5sum | cut -c1-8 | tr a-z A-Z)
users_conf='<?xml version="1.0" encoding="UTF-8"?>'"\n"
users_conf+='<tomcat-users xmlns="http://tomcat.apache.org/xml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd" version="1.0">'"\n"
users_conf+='  <role rolename="tomcat" />'"\n"
users_conf+='  <role rolename="manager-gui" />'"\n"
users_conf+='  <role rolename="admin-gui" />'"\n"
users_conf+='  <user username="manager" password="'$tomcat_admin_psw'" roles="manager-gui" />'"\n"
users_conf+='  <user username="admin" password="'$tomcat_admin_psw'" roles="tomcat,manager-gui,admin-gui" />'"\n"
users_conf+='</tomcat-users>'"\n"
echo -e $users_conf > /usr/share/tomcat9x/conf/tomcat-users.xml

## Create startup script
command='#!/bin/bash'"\n"
command+='echo "Launching Tomcat..."'"\n"
command+='export JAVA_HOME=`/usr/libexec/java_home -v 11.0.15`'"\n"
command+='/usr/share/tomcat9x/bin/shutdown.sh'"\n"
command+='/usr/share/tomcat9x/bin/startup.sh'
echo -e $command > /usr/share/tomcat9x/startup.sh
sudo chown $USER /usr/share/tomcat9x/startup.sh
sudo chmod +x /usr/share/tomcat9x/startup.sh

## Create start command on Desktop.
command='#!/bin/bash'"\n"
command+='/usr/share/tomcat9x/startup.sh'"\n"
command+='echo "Opening Tomcat host on web browser..."'"\n"
command+='sleep 5'"\n"
command+='nohup xdg-open http://localhost:8080/ >/dev/null 2>&1'
echo -e $command > ~/Desktop/tomcat-start.sh
sudo chmod +x ~/Desktop/tomcat-start.sh

## Create stop command on Desktop.
command='#!/bin/bash'"\n"
command+='export JAVA_HOME=`/usr/libexec/java_home -v 11.0.15`'"\n"
command+='echo "Stopping Tomcat..."'"\n"
command+='/usr/share/tomcat9x/bin/shutdown.sh'
echo -e $command > ~/Desktop/tomcat-stop.sh
sudo chmod +x ~/Desktop/tomcat-stop.sh

## Create open Tomcat folder command on Desktop.
command='#!/bin/bash'
command+="\n"
command+='nohup xdg-open /usr/share/tomcat9x >/dev/null 2>&1'
echo -e $command > ~/Desktop/tomcat-folder.sh
sudo chmod +x ~/Desktop/tomcat-folder.sh

echo "Installed Tomcat $user_selected_version_a with Redisson $user_selected_redisson_version."
echo "Tomcat Admin password: $tomcat_admin_psw"

## Open Tomcat folder.
nohup xdg-open ~/Desktop >/dev/null 2>&1
nohup xdg-open /usr/share/tomcat9x >/dev/null 2>&1
