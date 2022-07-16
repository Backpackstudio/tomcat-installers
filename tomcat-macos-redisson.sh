#!/bin/bash

# Download Tomcat 9.0.58
echo 'Downloading Tomcat 9.0.58 ...'
cd ~/Downloads
curl -L https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.58/bin/apache-tomcat-9.0.58.zip > apache-tomcat-9.0.58.zip
unzip -qq apache-tomcat-9.0.58.zip

# Download Redisson
echo 'Downloading Redisson 3.16.5 ...'
curl -L https://repo1.maven.org/maven2/org/redisson/redisson-tomcat-9/3.16.5/redisson-tomcat-9-3.16.5.jar > redisson-tomcat-9-3.16.5.jar
curl -L https://repo1.maven.org/maven2/org/redisson/redisson-all/3.16.5/redisson-all-3.16.5.jar > redisson-all-3.16.5.jar
mv ~/Downloads/{redisson-all-3.16.5.jar,redisson-tomcat-9-3.16.5.jar} ~/Downloads/apache-tomcat-9.0.58/lib

echo 'Installing Tomcat'
## Move Tomcat to final location
mv apache-tomcat-9.0.58 tomcat9
sudo mkdir -p /usr/local
sudo rm -f /Library/tomcat9
sudo rm -f -r /usr/local/tomcat9
sudo mv ~/Downloads/tomcat9 /usr/local
sudo ln -s /usr/local/tomcat9 /Library/tomcat9
sudo chown -R $USER /Library/tomcat9
sudo chmod +x /Library/tomcat9/bin/*.sh

## Create Redis conf
redis_conf='singleServerConfig:'"\n"
redis_conf+='  address: "redis://127.0.0.1:6379"'"\n"
redis_conf+='  database: 0'"\n"
echo -e $redis_conf > /Library/tomcat9/conf/redisson.yaml

## Add Redisson Session Manager
replace_a='<Context reloadable="true" crossContext="true" sessionCookiePath="\/">\n'
replace_a+='\n	<ResourceLink name="redissonsess" global="redissonsess" type="org.redisson.api.RedissonClient" \/>'
replace_a+='\n	<Manager className="org.redisson.tomcat.JndiRedissonSessionManager" readMode="REDIS" jndiName="redissonsess" updateMode="AFTER_REQUEST" broadcastSessionEvents="true" keyPrefix="ts" \/>\n'
sed -i '.bak' "s/<Context>/$replace_a/g" /Library/tomcat9/conf/context.xml

## Add Redisson data source
replace_b='<GlobalNamingResources>\n\n'
replace_b+='		<Resource name="redissonsess" auth="Container" factory="org.redisson.JndiRedissonFactory" configPath="${catalina.base}\/conf\/redisson.yaml" closeMethod="shutdown" \/>\n'
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
command+='cd /Library/tomcat9/bin/shutdown.sh'
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

echo "Tomcat Admin password: $tomcat_admin_psw"

## Open Tomcat folder.
open ~/Desktop
open /Library/tomcat9
