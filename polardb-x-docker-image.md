## 简介
PolarDB-X 是一款分布式数据库系统，其核心组件由 CN、DN、GMS 和 CDC 四个部分组成，实际运行中，每个组件是一个单独的进程。

本文围绕 3 个场景介绍 PolarDB-X 的镜像使用方式。

## 快速体验 PolarDB-X
基于 PolarDB-X Docker 镜像，可快速在本地运行一个 PolarDB-X 实例并开始体验。

首先将镜像下载到本地：

```shell
docker pull polardb-x
```

之后运行如下命令启动一个 PolarDB-X 容器：

```shell
docker run -d --name polardb-x -p 3306:8527 polardb-x
```

之后即可通过 MySQL Client 连接到 PolarDB-X ：

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
show master status ;
show binlog events in 'binlog.000001' from 4;


# 检查DN和CN
show storage ;  
show mpp ;
```

以上过程在本地运行了一个 PolarDB-X 容器，容器中运行了1个CN进程，1个DN进程（该进程同时扮演GMS角色）和一个CDC进程，并且使用默认参数进行了系统初始化，初始化完成后通过8527端口对外提供服务。

## 基于 GalaxySQL 进行开发
GalaxyEngine（即 DN ） 是 MySQL 8.x 的一个分支，可参考 MySQL 官方文档进行相关开发工作。

本文主要讲解如何用 IntelliJ IDEA + PolarDB-X Docker 镜像搭建 GalaxySQL（即 CN） 开发环境。

### 启动 DN&GMS容器
CN 的运行依赖DN和GMS，GMS可以看做一个扮演特殊角色的DN，所以在进行CN开发时，可用一个容器同时扮演DN和GMS的角色。运行这样一个容器的命令如下：

```shell
docker run -d --name polardb-x --env mode=dev -p 4886:4886 -p 32886:32886 -v polardb-x-data:/home/admin/polardb-x/ polardb-x
```

该命令会启动一个名叫 polardb-x 的容器，通过环境变量 `mode` 设置容器运行模式为开发模式（即 `mode=dev`）并将 MySQL 协议端口和私有协议端口暴露出来以供 CN 使用。
数据卷映射可以将数据保存下来，以便后续使用。
`mode` 所有取值见最后一个小节。

之后开始配置 CN 相关的内容。

### 配置 server.properties
首先修改代码中 polardbx-server/src/main/conf/server.properties 文件:

1. 将`serverPort`改为 `8527`
2. 将`metaDbAddr` 改为 `127.0.0.1:4886`
3. 将`metaDbXprotoPort` 改为 `32886`
4. 在shell中执行这行命令以获取`metaDbPasswd`：`mysql -h127.1 -P4886 -uroot -padmin -D polardbx_meta_db_polardbx -e "select passwd_enc from storage_info where inst_kind=2"`，之后增加配置： `metaDbPasswd=<查询到的密码>`
5. 增加`metaDbPasswd=my_polarx_passwd` 。

然后开始配置 IntelliJ IDEA 相关参数。

### 配置 IntelliJ IDEA
设置启动类为 `TddlLauncher`，VM配置（VM Options）增加 `-Dserver.conf=<server.properties文件路径>` 。
设置环境变量（Environment Variables） `dnPasswordKey=asdf1234ghjk5678`
由于 CN 编译过程比较耗内存，所以需要同时设置以下两个编译参数:

6. Preference-Compiler-Build process heap size 设置为 4096.
7. Preference-Build, Execution, -Build tools - maven - importing - VM options for importer 设置为 -Xmx2048m -Xms2048m.

至此 CN 的运行环境便配置好了，之后可以启动 `TddlLauncher` 进行相关开发和调试。


## mode 取值及含义

| mode 取值  | 含义                                       |
|----------|------------------------------------------|
| play     | 默认值，即体验模式，该模式会初始化并启动一个完整的 PolarDB-X 实例   |
| dev      | 开发模式，该模式会在容器内部初始化并启动一个DN进程，该进程同时会扮演GMS角色 |
| dev-dist | 分布式开发模式，部分特性需要在多DN的场景下进行开发和测试，此时可以启动多个DN |
| cn       | cn模式，用于生产环境，该容器内仅启动一个 CN 进程              |
| dn       | dn模式，用于生产环境，该容器内仅启动一个 DN 进程              |
| gms      | gms模式，用于生产环境，该容器内仅启动一个 GMS 进程            |
| cdc      | cdc模式，用于生产环境，该容器内仅启动一个 CDC 进程            |

