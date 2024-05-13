## 简介
PolarDB-X 是一款分布式数据库系统，其核心组件由 CN、DN、GMS 和 CDC 四个部分组成，实际运行中，每个组件是一个单独的进程。

本文围绕 3 个场景介绍 PolarDB-X 的镜像使用方式。

## 1. 基于docker 快速体验 PolarDB-X

基于 PolarDB-X Docker 镜像，可快速在本地运行一个 PolarDB-X 实例并开始体验。
首先将镜像下载到本地：

```shell
docker pull polardbx/polardb-x
```

之后运行如下命令启动一个 PolarDB-X 容器，建议docker内存>=12GB (CN/DN/CDC各自分配mem_size=4096MB)：

```shell
docker run -d --name polardb-x -m 12GB -p 3306:8527 -v /etc/localtime:/etc/localtime polardbx/polardb-x
```

等待之后即可通过 MySQL Client 连接到 PolarDB-X ：

```shell
mysql -h127.0.0.1 -upolardbx_root -p123456
```

PolarDB-X 高度兼容 MySQL 语法，与分布式相关的特性会对 SQL 语法进行扩展，可通过以下 SQL 指令初步体验 PolarDB-X:

```mysql
# 检查GMS 
select * from information_schema.schemata;

# 创建分区表
create database polarx_example mode='auto';

use polarx_example;

create table example (
  `id` bigint(11) auto_increment NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `score` bigint(11) DEFAULT NULL,
  primary key (`id`)
) engine=InnoDB default charset=utf8 
partition by hash(id) 
partitions 8;

insert into example values(null,'lily',375),(null,'lisa',400),(null,'ljh',500);

select * from example;

show topology from example;

# 检查CDC
show master status;
show binlog events in 'binlog.000001' from 4;


# 检查DN和CN
show storage;  
show mpp;
```

以上过程在本地运行了一个 PolarDB-X 容器，容器中运行了1个CN进程，1个DN进程（该进程同时扮演GMS角色）和一个CDC进程，并且使用默认参数进行了系统初始化，初始化完成后通过8527端口对外提供服务。

## 场景2. 手工调整 docker 内组件配置

您可以通过传递环境变量 `mem_size` 来控制 CN 和 CDC 的内存占用，CN 和 CDC 会***分别***占用不超过 `mem_size(MB)` 的内存。
同时，DN 的 buffer pool size 将设置为 `0.3*mem_size` 。此外，DN 的 my.cnf 文件以及数据文件位于容器内 `/home/polarx/polardbx/build/run/polardbx-engine/data` 这个目录下。
您可以将该目录挂载到本地，然后暂停 (stop) 容器，修改 mycnf，再启动 (start) 容器。接下来，我们用一个例子说明这些配置项：

1. 首先运行 polardb-x 容器，传递 mem_size 和 disk_size (用于配置 CDC) 环境变量 (单位都是 MB)，并将数据目录挂载到本地：
```shell
docker run -d --name polardb-x -p 3306:8527 --env mem_size=8192 --env disk_size=20480 -v /etc/localtime:/etc/localtime -v polardbx-data:/home/polarx/polardbx/build/run/polardbx-engine/data polardbx/polardb-x
```
上述指令，使得 CN 、DN、 CDC 分别占用不超过 8GB 内存，即一共占用不超过 24GB 内存。
同时，DN 的 `innodb_buffer_pool_size` 将设置为 `0.3*8192 MB`，最终取整为 2560MB。

2. 如果要修改 my.cnf，待容器启动后，先暂停容器的运行
```shell
docker stop polardb-x 
```

3. 找到本地挂载的目录
```shell
docker volume inspect polardbx-data
```
通过上述指令找到 `Mountpoint`，进入该目录，修改其中的 `my.cnf` 然后保存

4. 最后再重新启动容器
```shell
docker start polardb-x 
```

## 场景3. 基于 polardbx-sql 进行开发

polardbx-engine（即 DN ） 是 MySQL 8.x 的一个分支，可参考 MySQL 官方文档进行相关开发工作。

本文主要讲解如何用 IntelliJ IDEA + PolarDB-X Docker 镜像搭建 polardbx-sql（即 CN） 开发环境。

### 启动 DN&GMS 容器
CN 的运行依赖DN和GMS，GMS可以看做一个扮演特殊角色的DN，所以在进行CN开发时，可用一个容器同时扮演DN和GMS的角色。运行这样一个容器的命令如下：

```shell
docker run -d --name polardb-x --env mode=dev -p 4886:4886 -p 34886:34886 -v /etc/localtime:/etc/localtime -v polardb-x-data:/home/polarx/polardbx/build/run/polardbx-engine/data polardbx/polardb-x
```

该命令会启动一个名叫 polardb-x 的容器，通过环境变量 `mode` 设置容器运行模式为开发模式（即 `mode=dev`）并将 MySQL 协议端口和私有协议端口暴露出来以供 CN 使用。
数据卷映射可以将数据保存下来，以便后续使用。
`mode` 所有取值见最后一个小节。

之后开始配置 CN 相关的内容。

### 配置 server.properties
首先修改代码中 polardbx-server/src/main/resources/server.properties 文件:

1. 将`serverPort`改为 `8527`
2. 将`metaDbAddr` 改为 `127.0.0.1:4886`
3. 将`metaDbXprotoPort` 改为 `34886`
4. 将`galaxyXProtocol` 改为 `2`
5. 执行以下命令以获取`metaDbPasswd`：`docker exec polardb-x bash -c 'mysql -h127.1 -P4886 -uroot -D polardbx_meta_db_polardbx -e "select passwd_enc from storage_info where inst_kind=2"'` 
6. 增加`metaDbPasswd=<查询到的密码>` 。

然后开始配置 IntelliJ IDEA 相关参数。

### 配置 IntelliJ IDEA
设置环境变量（Environment Variables） `dnPasswordKey=asdf1234ghjk5678`
由于 CN 编译过程比较耗内存，所以需要同时设置以下两个编译参数:

6. Preference-Compiler-Build process heap size 设置为 4096.
7. Preference-Build, Execution, -Build tools - maven - importing - VM options for importer 设置为 -Xmx2048m -Xms2048m.

至此 CN 的运行环境便配置好了，之后可以启动 `TddlLauncher` 进行相关开发和调试。

### 远程部署 DN，本地开发 CN
当然，上述过程也可以在远程机器上部署 docker 容器来运行 polardbx-engine，
对外开放相应端口（4886，34886），然后：
1. 修改本地的 resources/server.properties 文件中的相应 ip，
把 127.0.0.1 改成远程机器 ip。
2. 登录远程机器，执行 `docker exec -it polardb-x bash` 登进 DN 容器。
3. 修改 storage_info 的 ip 为远程机器 ip：`mysql -h127.1 -P4886 -uroot -Dpolardbx_meta_db_polardbx -e "update storage_info set ip='<远程机器 ip>'"`。
4. 本地启动 `TddlLauncher` 即可。

## 附录

### 1. mode 取值及含义

| mode 取值  | 含义                                             |
|----------|------------------------------------------------|
| play     | 默认值，即体验模式，该模式会初始化并启动一个完整的 PolarDB-X 实例         |
| dev      | 开发模式，该模式会在容器内部初始化并启动一个DN进程，该进程同时会扮演GMS角色       |
| dev-dist | (尚未支持)分布式开发模式，部分特性需要在多DN的场景下进行开发和测试，此时可以启动多个DN |
| cn       | (尚未支持)cn模式，用于生产环境，该容器内仅启动一个 CN 进程              |
| dn       | (尚未支持)dn模式，用于生产环境，该容器内仅启动一个 DN 进程              |
| gms      | (尚未支持)gms模式，用于生产环境，该容器内仅启动一个 GMS 进程            |
| cdc      | (尚未支持)cdc模式，用于生产环境，该容器内仅启动一个 CDC 进程            |


### 2. docker build

```shell
git clone https://github.com/polardb/polardbx.git
make

cd docker && sh image-build.sh /home/polarx/polardbx/build
```
