# Windows下编译运行PolarDB-X

## 安装WSL
参考官方文档：https://docs.microsoft.com/en-us/windows/wsl/install

## 安装CentOS 7
微软商店里没有提供CentOS 7，可以在这里下载：https://github.com/mishamosher/CentOS-WSL/releases

验证过的版本是：https://github.com/mishamosher/CentOS-WSL/releases/tag/7.9-2111

解压后运行CentOS7.exe（右键以管理员身份运行）即可完成安装，再次运行CentOS7.exe即可打开一个终端。

## 环境准备
1. 安装wget： 
```
yum install wget -y
```

2. 使用阿里云的yum仓库：
```
cd /etc/yum.repos.d/ && \
wget -O CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo && \
yum clean all

cd /root
```

3. 安装工具链
```
yum install -y git

yum install -y centos-release-scl

yum install -y mysql

yum install -y java-1.8.0-openjdk-devel

yum install -y make automake openssl-devel ncurses-devel bison libaio-devel

yum install -y devtoolset-7-gcc devtoolset-7-gcc-c++ devtoolset-7-binutils

echo "source /opt/rh/devtoolset-7/enable" >>/etc/profile && source /etc/profile
```

4. 安装cmake：

仓库里没有cmake3，需要从源码编译安装

```
wget https://cmake.org/files/v3.23/cmake-3.23.2.tar.gz && tar -zxvf cmake-3.23.2.tar.gz && cd cmake-3.23.2/
./bootstrap && gmake && gmake install 
```

5. 创建admin用户：

CN与DN都不允许以root用户启动，需要创建一个用户。
```
useradd -ms /bin/bash admin && \
echo "admin:admin" | chpasswd && \
echo "admin    ALL=(ALL)    NOPASSWD: ALL" >> /etc/sudoers &&   \
su admin

cd /home/admin
```

6. 安装maven：

仓库中的maven版本太老了，装一个最新版本。
```
wget https://dlcdn.apache.org/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz && tar -zxvf apache-maven-3.8.6-bin.tar.gz

echo 'PATH=/home/admin/apache-maven-3.8.6/bin:$PATH' >> /home/admin/.bashrc && \
    echo "export PATH" >> /home/admin/.bashrc && \
	source  /home/admin/.bashrc
```

国内使用阿里云的maven仓库比较快，https://developer.aliyun.com/mvn/guide

修改maven的配置文件：
```
vi /home/admin/apache-maven-3.8.6/conf/settings.xml
```
在`<mirrors></mirrors>`标签中添加 mirror 子节点：
```
<mirror>
  <id>aliyunmaven</id>
  <mirrorOf>*</mirrorOf>
  <name>阿里云公共仓库</name>
  <url>https://maven.aliyun.com/repository/public</url>
</mirror>
```

## 编译PolarDB-X

1. 下载编译工程
```
git clone https://github.com/ApsaraDB/PolarDB-X.git

cd PolarDB-X
```

2. 编译
```
make
```

注意：如果机器内存<=16G，请修改PolarDB-X/Makefile中编译的并行度，否则容易出现OOM，将8修改为2

![image](https://user-images.githubusercontent.com/2645985/173988137-dc514bdc-342f-4a4e-ae05-88f0ff44898a.png)


3. 运行
```
./build/run/bin/polardb-x.sh start
```

4. 停止
```
./build/run/bin/polardb-x.sh stop
```


## 使用IDEA开发GalaxySQL（CN）

我们使用IDEA来运行CN的代码，并使用CentOS中启动的GalaxyEngine节点作为GMS与DN节点。

1. WSL与Windows是同一个LAN内的两个IP，在上述的Demo中，GMS中记录的DN的IP为`127.0.0.1`，Windows无法直接通过这个IP来访问与GMS/DN，因此需要获取到WSL的LAN IP，并做相应的替换。

在CentOS中执行`ip addr`，记录eth0中的IP，如本例中，IP为`172.27.47.106`

```
ip addr

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: bond0: <BROADCAST,MULTICAST,MASTER> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 7a:44:78:58:e8:32 brd ff:ff:ff:ff:ff:ff
3: dummy0: <BROADCAST,NOARP> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether 7a:e5:bd:1e:a3:ba brd ff:ff:ff:ff:ff:ff
4: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
5: sit0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/sit 0.0.0.0 brd 0.0.0.0
6: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 00:15:5d:05:db:9b brd ff:ff:ff:ff:ff:ff
    inet 172.27.47.106/20 brd 172.27.47.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::215:5dff:fe05:db9b/64 scope link
       valid_lft forever preferred_lft forever
```

2. 在CentOS上登录GMS，并修改DN的IP。

```
 mysql -h127.1 -P4886 -uroot polardbx_meta_db_polardbx -e 'update storage_info set ip="172.27.47.106";'
```

3. Kill掉CentOS中的CN进程，避免冲突：

```
[admin@DESKTOP-UGTN860 PolarDB-X]$ jps
13174 Jps
15625 DaemonBootStrap
16105 DumperBootStrap
16139 TaskBootStrap
17334 TddlLauncher
[admin@DESKTOP-UGTN860 PolarDB-X]$ kill -9 17334
```
4. 在Windows中clone代码：

```
git clone https://github.com/ApsaraDB/galaxysql.git

cd galaxysql

git submodule update --init
```

5. 在IDEA中打开该maven工程，并修改IDEA的maven仓库为阿里云的maven仓库：

![image](https://user-images.githubusercontent.com/2645985/173986060-a0cdba7e-04b6-46bf-a76c-66582c83d630.png)

6. 调整IDEA编译的内存上限：

![image](https://user-images.githubusercontent.com/2645985/173986190-f647d8d7-4188-4f29-854c-a906f0686ca2.png)

7. 使用CentOS中的`PolarDB-X/build/run/galaxysql/conf/server.properties`内容覆盖IDEA中CN的`galaxysql\polardbx-server\src\main\resources`，并将`metaDbAddr`中的`127.0.0.1`修改为WSL的IP：

![image](https://user-images.githubusercontent.com/2645985/173987557-9b2f72aa-25a9-4149-b1c9-8a05cd26c19d.png)
  
8. 运行一次`com.alibaba.polardbx.server.TddlLauncher`，此时会启动失败

9. 修改`TddlLauncher`的`Run/Debug Configurations`，添加`dnPasswordKey=asdf1234ghjk5678
`到环境变量中：


![image](https://user-images.githubusercontent.com/2645985/173987036-5aa9560f-c1b7-4451-b164-82c457b0b597.png)
![image](https://user-images.githubusercontent.com/2645985/173987081-4767f56b-20ce-43a7-9cff-f35fa01ab5ca.png)
![image](https://user-images.githubusercontent.com/2645985/173987109-7ca46936-7f87-4c16-a0fe-73c7d5ab9bde.png)

10. 再次运行`com.alibaba.polardbx.server.TddlLauncher`即可

11. mysql终端可以连上本地的CN了

```
mysql -h 127.0.0.1 -upolardbx_root -p123456 -P8527
```

## 固定WSL的IP地址

注意，WSL2每次重启都会重新分配一个IP，这会导致GMS与`server.properties`中记录的IP失效。有一个折中的方法，执行以下命令，会分别为WSL2与Windows分配一个指定的IP地址：

```
wsl -d CentOS7 -u root ip addr add 192.168.50.2/24 broadcast 192.168.50.255 dev eth0 label eth0:1
netsh interface ip add address “vEthernet (WSL)” 192.168.50.1 255.255.255.0
```

这样可以将GMS与`server.properties`中的IP固定为`192.168.50.2`即可。

同时，可以将这两行命令保存为脚本加到启动项中，这样重启系统后会自动完成IP的设置。
