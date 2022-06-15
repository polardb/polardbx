# Windows下编译运行PolarDB-X

## 安装WSL
参考官方文档：https://docs.microsoft.com/en-us/windows/wsl/install

建议安装并升级到WSL2（后续可以用来运行Docker）

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
yum clean all && \
cd /root
```

3. 安装工具链
```
yum install  -y git
yum install -y centos-release-scl
yum install -y mysql
yum  install -y java-1.8.0-openjdk-devel
yum install -y make automake  openssl-devel ncurses-devel bison libaio-devel
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
su admin && \
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

3. 运行
```
./build/run/bin/polardb-x.sh start
```

4. 停止
```
./build/run/bin/polardb-x.sh stop
```
