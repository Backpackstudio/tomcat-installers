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
mv "apache-tomcat-$user_selected_version_a" tomcat9
sudo mkdir -p /usr/local
sudo rm -f /Library/tomcat9
sudo rm -f -r /usr/local/tomcat9
sudo mv ~/Downloads/tomcat9 /usr/local
sudo ln -s /usr/local/tomcat9 /Library/tomcat9

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
mv ~/Downloads/{"redisson-all-$user_selected_redisson_version.jar","redisson-tomcat-9-$user_selected_redisson_version.jar"} /Library/tomcat9/lib

sudo chown -R $USER /Library/tomcat9
sudo chmod +x /Library/tomcat9/bin/*.sh

## Create tomcat Native conf
tomcat_native='#!/bin/sh'"\n"
tomcat_native+='# Set path to Tomcat Native.'"\n"
tomcat_native+='CATALINA_OPTS="$CATALINA_OPTS -Djava.library.path=/usr/local/opt/tomcat-native/lib"'
echo -e $tomcat_native > /Library/tomcat9/bin/setenv.sh
chomd +x /Library/tomcat9/bin/setenv.sh

## Create Redis conf
redis_conf='singleServerConfig:'"\n"
redis_conf+='  address: "redis://127.0.0.1:6379"'"\n"
redis_conf+='  database: 0'
echo -e $redis_conf > /Library/tomcat9/conf/redisson.yaml

## Silence TLD flood
echo -e "\n"'org.apache.jasper.servlet.TldScanner.level = WARNING'"\n" >> /Library/tomcat9/conf/logging.properties

## Add Redisson Session Manager
replace_a='<Context reloadable="true" crossContext="true" sessionCookiePath="\/">\n'
replace_a+='\n	<ResourceLink name="bean/redisson" global="bean/redisson" type="org.redisson.api.RedissonClient" \/>'
replace_a+='\n	<Manager className="org.redisson.tomcat.Jndibean/redissonionManager" readMode="REDIS" jndiName="bean/redisson" updateMode="AFTER_REQUEST" broadcastSessionEvents="true" broadcastSessionUpdates="true" keyPrefix="tms" \/>\n'
sed -i '.bak' "s/<Context>/$replace_a/g" /Library/tomcat9/conf/context.xml

## Add Redisson data source
replace_b='<GlobalNamingResources>\n\n'
replace_b+='		<Resource name="bean/redisson" auth="Container" factory="org.redisson.JndiRedissonFactory" configPath="${catalina.base}\/conf\/redisson.yaml" closeMethod="shutdown" \/>\n'
sed -i '.bak' "s/<GlobalNamingResources>/$replace_b/g" /Library/tomcat9/conf/server.xml

## Edit Tomcat users
tomcat_admin_psw='P'$(date | md5 | cut -c1-8 | tr a-z A-Z)
users_conf='<?xml version="1.0" encoding="UTF-8"?>'"\n"
users_conf+='<tomcat-users xmlns="http://tomcat.apache.org/xml" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd" version="1.0">'"\n"
users_conf+='  <role rolename="tomcat" />'"\n"
users_conf+='  <role rolename="manager-gui" />'"\n"
users_conf+='  <role rolename="admin-gui" />'"\n"
users_conf+='  <user username="manager" password="'$tomcat_admin_psw'" roles="manager-gui" />'"\n"
users_conf+='  <user username="admin" password="'$tomcat_admin_psw'" roles="tomcat,manager-gui,admin-gui" />'"\n"
users_conf+='</tomcat-users>'"\n"
echo -e $users_conf > /Library/tomcat9/conf/tomcat-users.xml

## Create startup script
command='#!/bin/bash'"\n"
command+='echo "Launching Tomcat..."'"\n"
command+='export JAVA_HOME=`/usr/libexec/java_home -v 11.0.15.0.1`'"\n"
command+='/Library/tomcat9/bin/shutdown.sh'"\n"
command+='/Library/tomcat9/bin/startup.sh'
echo -e $command > /Library/tomcat9/startup.sh
sudo chown $USER /Library/tomcat9/startup.sh
sudo chmod +x /Library/tomcat9/startup.sh

## Create start command on Desktop.
command='#!/bin/bash'"\n"
command+='/Library/tomcat9/startup.sh'"\n"
command+='echo "Opening Tomcat host on web browser..."'"\n"
command+='sleep 5'"\n"
command+='open http://localhost:8080/'
echo -e $command > ~/Desktop/tomcat-start.command
sudo chmod +x ~/Desktop/tomcat-start.command
SetFile -a E ~/Desktop/tomcat-start.command

## Create stop command on Desktop.
command='#!/bin/bash'"\n"
command+='export JAVA_HOME=`/usr/libexec/java_home -v 11.0.15.0.1`'"\n"
command+='echo "Stopping Tomcat..."'"\n"
command+='/Library/tomcat9/bin/shutdown.sh'
echo -e $command > ~/Desktop/tomcat-stop.command
sudo chmod +x ~/Desktop/tomcat-stop.command
SetFile -a E ~/Desktop/tomcat-stop.command

## Create open Tomcat folder command on Desktop.
command='#!/bin/bash'
command+="\n"
command+='open /Library/tomcat9'
echo -e $command > ~/Desktop/tomcat-folder.command
sudo chmod +x ~/Desktop/tomcat-folder.command
SetFile -a E ~/Desktop/tomcat-folder.command

echo "Installed Tomcat $user_selected_version_a with Redisson $user_selected_redisson_version."
echo "Tomcat Admin password: $tomcat_admin_psw"

## Open Tomcat folder.
open ~/Desktop
open /Library/tomcat9
