# Tomcat Install Scripts

Scripts for installing Tomcat.

Make sure that you have installed `tomcat-native` and `redis` on you machine and have appropriate Java JDK  available.

## Install Tomcat with Redisson on macOS

To install `tomcat-native`:

```shell
brew install tomcat-native
```

To install `redis`:

```shell
brew install redis
```

### Install Tomcat with Redisson:

Download installer and execute it. Select desired versions when prompted.

```shell
cd ~/Downloads
curl -L https://raw.githubusercontent.com/Backpackstudio/tomcat-installers/main/tomcat-macos-redisson.sh > tomcat-macos-redisson.sh
chmod +x tomcat-macos-redisson.sh
./tomcat-macos-redisson.sh
```

## Install Tomcat with Redisson on Linux (Ubuntu)

### Install Redis server:

```shell
sudo apt update
sudo apt install redis-server
```

Change `supervised no` to `supervised systemd`:

```shell
sudo nano /etc/redis/redis.conf
sudo systemctl restart redis.service
systemctl status redis
```

### Install Java:

```shell
sudo apt update
sudo apt install openjdk-11-jdk
java -version
```

### Install Tomcat Native:

```shell
sudo apt install libtcnative-1 libapr1-dev
```

### Install Tomcat with Redisson

Download installer and execute it. Select desired versions when prompted.

```shell
cd ~/Downloads
curl -L https://raw.githubusercontent.com/Backpackstudio/tomcat-installers/main/tomcat-linux-redisson.sh > tomcat-linux-redisson.sh
chmod +x tomcat-linux-redisson.sh
./tomcat-linux-redisson.sh
```

