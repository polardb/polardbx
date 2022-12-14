BUILD_DIR = $(shell pwd)/build
CN_CONF = $(BUILD_DIR)/run/galaxysql/conf/server.properties
DN_CONF =  $(BUILD_DIR)/run/galaxyengine/my.cnf
CDC_CONF = $(BUILD_DIR)/run/galaxycdc/polardbx-binlog.standalone/conf/config.properties
CN_STARTUP = $(BUILD_DIR)/run/galaxysql/bin/startup.sh
CDC_STARTUP = $(BUILD_DIR)/run/galaxycdc/polardbx-binlog.standalone/bin/start.sh

UNAME_S = $(shell uname -s)
OS = $(shell lsb_release -si)
V = $(shell lsb_release -r | awk '{print $$2}'|awk -F"." '{print $$1}')
CPU_CORES = $(shell cat /proc/cpuinfo | grep processor| wc -l)

export CFLAGS := -O3 -g -fexceptions -static-libgcc -fno-omit-frame-pointer -fno-strict-aliasing
export CXXFLAGS := -O3 -g -fexceptions -static-libgcc -fno-omit-frame-pointer -fno-strict-aliasing

.PHONY: polardb-x
polardb-x: gms dn cn cdc configs
	cd $(BUILD_DIR)/run ; \
	if [ -d "bin" ]; then \
		rm -rf bin; \
	fi; \
	mkdir bin; \
	echo "$$START_SCRIPT" > bin/polardb-x.sh; \
	chmod +x bin/polardb-x.sh
	chmod +x $(BUILD_DIR)/run/galaxysql/bin/startup.sh
	chmod +x $(BUILD_DIR)/run/galaxycdc/polardbx-binlog.standalone/bin/daemon.sh

.PHONY: gms
gms: sources deps
	. /etc/profile; \
	cd $(BUILD_DIR)/galaxyengine; \
	cmake . \
		-DFORCE_INSOURCE_BUILD=ON \
		-DSYSCONFDIR:PATH="$(BUILD_DIR)/run/galaxyengine/u01/mysql" \
		-DCMAKE_INSTALL_PREFIX:PATH="$(BUILD_DIR)/run/galaxyengine/u01/mysql" \
		-DCMAKE_BUILD_TYPE:STRING=RelWithDebInfo \
		-DWITH_NORMANDY_CLUSTER=ON \
		-DWITH_7U:BOOL=OFF \
		-DWITH_PROTOBUF:STRING=bundled \
		-DINSTALL_LAYOUT=STANDALONE \
		-DMYSQL_MAINTAINER_MODE=0 \
		-DWITH_EMBEDDED_SERVER=0 \
		-DWITH_SSL=openssl \
		-DWITH_ZLIB=bundled \
		-DWITH_MYISAM_STORAGE_ENGINE=1 \
		-DWITH_INNOBASE_STORAGE_ENGINE=1 \
		-DWITH_PARTITION_STORAGE_ENGINE=1 \
		-DWITH_CSV_STORAGE_ENGINE=1 \
		-DWITH_ARCHIVE_STORAGE_ENGINE=1 \
		-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
		-DWITH_FEDERATED_STORAGE_ENGINE=1 \
		-DWITH_PERFSCHEMA_STORAGE_ENGINE=1 \
		-DWITH_EXAMPLE_STORAGE_ENGINE=0 \
		-DWITH_TEMPTABLE_STORAGE_ENGINE=1 \
		-DWITH_XENGINE_STORAGE_ENGINE=0 \
		-DUSE_CTAGS=0 \
		-DWITH_EXTRA_CHARSETS=all \
		-DWITH_DEBUG=0 \
		-DENABLE_DEBUG_SYNC=0 \
		-DENABLE_DTRACE=0 \
		-DENABLED_PROFILING=1 \
		-DENABLED_LOCAL_INFILE=1 \
		-DWITH_BOOST="extra/boost/boost_1_70_0.tar.gz"; \
	make -j $(CPU_CORES) && make install
	rm -rf $(BUILD_DIR)/run/galaxyengine/u01/mysql/mysql-test

.PHONY: dn
dn: gms

.PHONY: cdc
cdc: sources deps cn
	. /etc/profile; \
	cd $(BUILD_DIR)/galaxycdc; \
	mvn -U clean install -Dmaven.test.skip=true -DfailIfNoTests=false -e -P release; \
	mkdir $(BUILD_DIR)/run/galaxycdc; \
	cp polardbx-cdc-assemble/target/polardbx-binlog.tar.gz $(BUILD_DIR)/run/galaxycdc/;	\
	cd $(BUILD_DIR)/run/galaxycdc/; \
	tar xzvf polardbx-binlog.tar.gz; \
	rm -f polardbx-binlog.tar.gz

.PHONY: cn
cn: sources deps
	. /etc/profile; \
	cd $(BUILD_DIR)/galaxysql; \
	mvn install -DskipTests -D env=release; \
	mkdir $(BUILD_DIR)/run/galaxysql; \
	cp target/polardbx-server-*.tar.gz $(BUILD_DIR)/run/galaxysql/;	\
	cd $(BUILD_DIR)/run/galaxysql; \
	tar xzvf polardbx-server-*.tar.gz; \
	rm -f xzvf polardbx-server-*.tar.gz

DN_DATA_DIR = $(BUILD_DIR)/run/galaxyengine/data
DN_BASE_DIR = $(BUILD_DIR)/run/galaxyengine

.PHONY: configs
configs: gms dn cdc cn
	# config gms & dn
	echo "$$MY_CNF" > $(DN_CONF)
	mkdir -p $(DN_DATA_DIR)/data
	mkdir -p $(DN_DATA_DIR)/log
	mkdir -p $(DN_DATA_DIR)/run
	mkdir -p $(DN_DATA_DIR)/tmp
	mkdir -p $(DN_DATA_DIR)/mysql
	# start gms
	if [ -e "$(DN_DATA_DIR)/data/auto.cnf" ]; then \
		echo "gms root account already initialized."; \
	else \
		$(BUILD_DIR)/run/galaxyengine/u01/mysql/bin/mysqld --defaults-file=$(DN_CONF) --initialize-insecure; \
	fi ; \
	$(BUILD_DIR)/run/galaxyengine/u01/mysql/bin/mysqld --defaults-file=$(DN_CONF) -D
	# config cn
	awk -F"=" '/^serverPort/{$$2="=8527";print;next}1' $(CN_CONF) > tmp && mv tmp $(CN_CONF)
	awk -F"=" '/^metaDbAddr/{$$2="=127.0.0.1:4886";print;next}1' $(CN_CONF) > tmp && mv tmp $(CN_CONF)
	awk -F"=" '/^metaDbXprotoPort/{$$2="=34886";print;next}1' $(CN_CONF) > tmp && mv tmp $(CN_CONF)
	awk -F"=" '/^galaxyXProtocol/{$$2="=2";print;next}1' $(CN_CONF) > tmp && mv tmp $(CN_CONF)
	sed -i 's/Xms[0-9]\+g/Xms2g/g' $(CN_STARTUP)
	sed -i 's/Xmx[0-9]\+g/Xmx2g/g' $(CN_STARTUP)
	sed -i 's/-XX:MaxDirectMemorySize=[0-9]\+g//g' $(CN_STARTUP)
	cd $(BUILD_DIR)/run/galaxysql/;	\
	META=`bin/startup.sh -I -P asdf1234ghjk5678 -d 127.0.0.1:4886:34886 -u polardbx_root -S "123456" 2>&1`; \
	echo "meta: $${META}"; \
	echo "$${META}" | grep "metaDbPass" >> meta.tmp; \
	META_DB_PASS=`cat meta.tmp | grep "metaDbPass"`; \
	echo "metadb password: $${META_DB_PASS}"; \
	ps aux|grep "$(BUILD_DIR)/run/galaxyengine/u01/mysql/bin/mysqld" | grep -v "grep" | awk '{print $$2}' |xargs kill; \
	if [ "" = "$${META_DB_PASS}" ]; then \
		echo "meta db init failed."; \
		exit 1; \
	fi;	\
	cat meta.tmp >> $(CN_CONF)
	# config cdc	
	cd $(BUILD_DIR)/run/galaxysql/;	\
	META_DB_PASS=`cat meta.tmp | awk -F"=" '{print $$2}'`; \
	awk -F"=" '/^useEncryptedPassword/{$$2="=true";print;next}1' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	awk -F"=" '/^polardbx.instance.id/{$$2="=polardbx-polardbx";print;next}1' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	awk -F"=" '/^metaDb_url/{$$2="=jdbc:mysql://127.0.0.1:4886/polardbx_meta_db_polardbx?useSSL=false";print;next}1' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	awk -F"=" '/^metaDb_username/{$$2="=my_polarx";print;next}1' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	sed 's/metaDb_password.*//g' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	cat meta.tmp >> $(CDC_CONF); \
	sed 's/metaDbPasswd/metaDb_password/g' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF);	\
	awk -F"=" '/^polarx_url/{$$2="=jdbc:mysql://127.0.0.1:8527/__cdc__";print;next}1' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	awk -F"=" '/^polarx_username/{$$2="=polardbx_root";print;next}1' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	awk -F"=" '/^polarx_password/{$$2="=UY1tQsgNvP8GJGGP8vHKKA==";print;next}1' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	sed -i 's/admin/polarx/g' $(CDC_CONF); \
	awk -F"=" '/^mem_size/{$$2="=2048";print;next}1' $(CDC_CONF) > tmp && mv tmp $(CDC_CONF); \
	sed -i 's/MEMORY=1204/MEMORY=512/g' $(CDC_STARTUP); \
	rm meta.tmp

.PHONY: sources
sources: deps
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR); \
	if [ -d "galaxysql" ]; then \
		echo "galaxysql exsits."; \
	else \
		git clone https://github.com/apsaradb/galaxysql.git; \
		cd galaxysql; \
		git submodule update --init; \
	fi
	cd $(BUILD_DIR); \
	if [ -d "galaxyengine" ]; then \
		echo "galaxyengine exists."; \
	else \
		git clone https://github.com/apsaradb/galaxyengine.git;	\
		cd galaxyengine; \
		wget https://boostorg.jfrog.io/artifactory/main/release/1.70.0/source/boost_1_70_0.tar.gz; \
		mkdir -p extra/boost; \
		cp boost_1_70_0.tar.gz extra/boost/; \
		if [ "$(UNAME_S)" = "Darwin" ]; then \
			echo "$${VERSION_PATCH}" >> macos.patch; \
			git apply macos.patch; \
			rm macos.patch; \
		fi ; \
	fi
	cd $(BUILD_DIR); \
	if [ -d "galaxycdc" ]; then \
		echo "galaxycdc exists."; \
	else \
		git clone https://github.com/apsaradb/galaxycdc.git; \
	fi

.PHONY: deps
deps:
ifeq ($(UNAME_S), Darwin)
	@echo "Install the following tools and libraries before your building.\n"
	@echo "tools		: cmake3, make, automake, gcc, g++, bison, git, jdk1.8+, maven3"
	@echo "libraries	: openssl1.1 \n\n"
	@echo "Press any key to continue..."
	@read -n 1
else
ifeq ($(OS), CentOS)
	sudo yum remove -y cmake
	sudo yum install -y epel-release
	sudo yum install -y wget java-1.8.0-openjdk-devel cmake3 automake bison openssl-devel ncurses-devel libaio-devel mysql
ifeq ($(V), 8)
	sudo yum install -y libtirpc-devel dnf-plugins-core
	sudo yum config-manager --set-enabled PowerTools
	sudo yum install -y rpcgen
	sudo yum groupinstall -y "Development Tools"
	sudo yum install -y gcc gcc-c++
endif
ifeq ($(V), 7)
	if [ -e "/usr/bin/cmake" ]; then \
		sudo rm /usr/bin/cmake -f ; \
	fi
	sudo ln -s /usr/bin/cmake3 /usr/bin/cmake
	sudo yum install -y centos-release-scl
	sudo yum install -y devtoolset-7-gcc devtoolset-7-gcc-c++ devtoolset-7-binutils
	if ! grep "source /opt/rh/devtoolset-7/enable" /etc/profile; then \
		echo "source /opt/rh/devtoolset-7/enable" | sudo tee -a /etc/profile ; \
	fi
endif
endif
ifneq ($(filter $(OS), Ubuntu CentOS),)
	if [ ! -d /opt/apache-maven-3.8.6 ]; then \
		sudo wget https://mirrors.aliyun.com/apache/maven/maven-3/3.8.6/binaries/apache-maven-3.8.6-bin.tar.gz -P /tmp && \
		sudo tar xf /tmp/apache-maven-3.8.6-bin.tar.gz -C /opt && \
		sudo rm -f /tmp/apache-maven-3.8.6-bin.tar.gz && \
		sudo ln -fs /opt/apache-maven-3.8.6 /opt/maven && \
		echo 'export M2_HOME=/opt/maven' | sudo tee /etc/profile.d/maven.sh && \
		echo 'export PATH=$${M2_HOME}/bin:$${PATH}' | sudo tee -a /etc/profile.d/maven.sh && \
		sudo chmod +x /etc/profile.d/maven.sh && \
		echo '<mirror>' | sudo tee /opt/maven/conf/settings.xml && \
		echo '<id>aliyunmaven</id>' | sudo tee -a /opt/maven/conf/settings.xml && \
		echo '<mirrorOf>*</mirrorOf>' | sudo tee -a /opt/maven/conf/settings.xml && \
		echo '<name>aliyun public</name>' | sudo tee -a /opt/maven/conf/settings.xml && \
		echo '<url>https://maven.aliyun.com/repository/public</url>' | sudo tee -a /opt/maven/conf/settings.xml && \
		echo '</mirror>' | sudo tee -a /opt/maven/conf/settings.xml; \
	fi
	if ! grep "source /etc/profile.d/maven.sh" /etc/profile; then \
		echo "source /etc/profile.d/maven.sh" | sudo tee -a /etc/profile ; \
	fi
endif
ifeq ($(OS), Ubuntu)
	sudo apt-get update
	sudo apt-get install -y git openjdk-8-jdk make automake cmake bison pkg-config libaio-dev libncurses5-dev \
		libsasl2-dev libldap2-dev libssl-dev gcc-7 g++-7 mysql-client
	sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 60 \
		 --slave /usr/bin/g++ g++ /usr/bin/g++-7
	sudo update-alternatives --config gcc
endif
endif

clean:
	rm -rf $(BUILD_DIR)/run

cleanAll:
	rm -rf $(BUILD_DIR)

# long variables

define START_SCRIPT
#!/bin/bash

PROG_NAME=$$0
ACTION=$$1

usage() {
    echo "Usage: $${PROG_NAME} [start | restart | stop]"
    exit 1;
}

if [ $$# -lt 1 ]; then
    usage
fi

start() {
	start_dn

	echo "start cn..."
	$(BUILD_DIR)/run/galaxysql/bin/startup.sh -P asdf1234ghjk5678
	echo "cn is running."

	echo "start cdc..."
	$(BUILD_DIR)/run/galaxycdc/polardbx-binlog.standalone/bin/daemon.sh start
	echo "cdc is running."

	echo "try polardb-x by:"
	echo "mysql -h127.1 -P8527 -upolardbx_root"
}

start_dn() {
	echo "start gms & dn..."
	$(BUILD_DIR)/run/galaxyengine/u01/mysql/bin/mysqld --defaults-file=$(DN_CONF) -D
	echo "gms and dn are running."
}

stop() {
	echo "stop cdc..."
	ps aux | grep "DaemonBootStrap" | grep -v "grep" | awk '{print $$2}'| xargs kill -9
	ps aux | grep "TaskBootStrap" | grep -v "grep" | awk '{print $$2}'| xargs kill -9
	ps aux | grep "DumperBootStrap" | grep -v "grep" | awk '{print $$2}'| xargs kill -9
	echo "cdc is stopped."

	echo "stop cn..."
	ps aux | grep "TddlLauncher" | grep -v "grep" | awk '{print $$2}' | xargs kill -9
	if [ -f "$(BUILD_DIR)/run/galaxysql/bin/tddl.pid" ]; then
		rm $(BUILD_DIR)/run/galaxysql/bin/tddl.pid
	fi
	echo "cn is stopped."

	echo "stop dn & gms..."
	ps aux | grep "$(BUILD_DIR)/run/galaxyengine/u01/mysql/bin/mysqld" | grep -v "grep" | awk '{print $$2}'| xargs kill
	echo "dn & gms are stopped."
}

case "$${ACTION}" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart)
        stop
        sleep 1
        start
    ;;
    start_dn)
    	start_dn
    ;;
    *)
        usage
    ;;
esac

endef
export START_SCRIPT

define MY_CNF
[mysqld]
auto_increment_increment = 1
auto_increment_offset = 1
autocommit = ON
automatic_sp_privileges = ON
avoid_temporal_upgrade = OFF
back_log = 3000
binlog_cache_size = 1048576
binlog_checksum = CRC32
binlog_order_commits = OFF
binlog_row_image = full
binlog_rows_query_log_events = ON
binlog_stmt_cache_size = 32768
binlog_transaction_dependency_tracking = WRITESET
block_encryption_mode = "aes-128-ecb"
bulk_insert_buffer_size = 4194304
character_set_server = utf8
concurrent_insert = 2
connect_timeout = 10
datadir = $(DN_DATA_DIR)/data
default_authentication_plugin = mysql_native_password
default_storage_engine = InnoDB
default_time_zone = +8:00
default_week_format = 0
delay_key_write = ON
delayed_insert_limit = 100
delayed_insert_timeout = 300
delayed_queue_size = 1000
disconnect_on_expired_password = ON
div_precision_increment = 4
end_markers_in_json = OFF
enforce_gtid_consistency = ON
eq_range_index_dive_limit = 200
event_scheduler = OFF
expire_logs_days = 0
explicit_defaults_for_timestamp = OFF
flush_time = 0
ft_max_word_len = 84
ft_min_word_len = 4
ft_query_expansion_limit = 20
general_log = OFF
general_log_file = $(DN_DATA_DIR)/log/general.log
group_concat_max_len = 1024
gtid_mode = ON
host_cache_size = 644
init_connect = ''
innodb_adaptive_flushing = ON
innodb_adaptive_flushing_lwm = 10
innodb_adaptive_hash_index = OFF
innodb_adaptive_max_sleep_delay = 150000
innodb_autoextend_increment = 64
innodb_autoinc_lock_mode = 2
innodb_buffer_pool_chunk_size = 33554432
innodb_buffer_pool_dump_at_shutdown = ON
innodb_buffer_pool_dump_pct = 25
innodb_buffer_pool_instances = 8
innodb_buffer_pool_load_at_startup = ON
innodb_change_buffer_max_size = 25
innodb_change_buffering = none
innodb_checksum_algorithm = crc32
innodb_cmp_per_index_enabled = OFF
innodb_commit_concurrency = 0
innodb_compression_failure_threshold_pct = 5
innodb_compression_level = 6
innodb_compression_pad_pct_max = 50
innodb_concurrency_tickets = 5000
innodb_data_file_purge = ON
innodb_data_file_purge_interval = 100
innodb_data_file_purge_max_size = 128
innodb_data_home_dir = $(DN_DATA_DIR)/mysql
innodb_deadlock_detect = ON
innodb_disable_sort_file_cache = ON
innodb_equal_gcn_visible = 0
innodb_flush_log_at_trx_commit = 1
innodb_flush_method = O_DIRECT
innodb_flush_neighbors = 0
innodb_flush_sync = ON
innodb_ft_cache_size = 8000000
innodb_ft_enable_diag_print = OFF
innodb_ft_enable_stopword = ON
innodb_ft_max_token_size = 84
innodb_ft_min_token_size = 3
innodb_ft_num_word_optimize = 2000
innodb_ft_result_cache_limit = 2000000000
innodb_ft_sort_pll_degree = 2
innodb_ft_total_cache_size = 640000000
innodb_io_capacity = 20000
innodb_io_capacity_max = 40000
innodb_lock_wait_timeout = 50
innodb_log_buffer_size = 209715200
innodb_log_checksums = ON
innodb_log_file_size = 2147483648
innodb_log_group_home_dir = $(DN_DATA_DIR)/mysql
innodb_lru_scan_depth = 8192
innodb_max_dirty_pages_pct = 75
innodb_max_dirty_pages_pct_lwm = 0
innodb_max_purge_lag = 0
innodb_max_purge_lag_delay = 0
innodb_max_undo_log_size = 1073741824
innodb_monitor_disable =
innodb_monitor_enable =
innodb_old_blocks_pct = 37
innodb_old_blocks_time = 1000
innodb_online_alter_log_max_size = 134217728
innodb_open_files = 20000
innodb_optimize_fulltext_only = OFF
innodb_page_cleaners = 4
innodb_print_all_deadlocks = ON
innodb_purge_batch_size = 300
innodb_purge_rseg_truncate_frequency = 128
innodb_purge_threads = 4
innodb_random_read_ahead = OFF
innodb_read_ahead_threshold = 0
innodb_read_io_threads = 4
innodb_rollback_on_timeout = OFF
innodb_rollback_segments = 128
innodb_snapshot_update_gcn = 1
innodb_sort_buffer_size = 1048576
innodb_spin_wait_delay = 6
innodb_stats_auto_recalc = ON
innodb_stats_method = nulls_equal
innodb_stats_on_metadata = OFF
innodb_stats_persistent = ON
innodb_stats_persistent_sample_pages = 20
innodb_stats_transient_sample_pages = 8
innodb_status_output = OFF
innodb_status_output_locks = OFF
innodb_strict_mode = ON
innodb_sync_array_size = 16
innodb_sync_spin_loops = 30
innodb_table_locks = ON
innodb_tcn_cache_level = block
innodb_thread_concurrency = 0
innodb_thread_sleep_delay = 0
innodb_write_io_threads = 4
interactive_timeout = 7200
key_buffer_size = 16777216
key_cache_age_threshold = 300
key_cache_block_size = 1024
key_cache_division_limit = 100
lc_time_names = en_US
local_infile = OFF
lock_wait_timeout = 1800
log-bin-index = $(DN_DATA_DIR)/mysql/mysql-bin.index
log_bin = $(DN_DATA_DIR)/mysql/mysql-bin.log
log_bin_trust_function_creators = ON
log_bin_use_v1_row_events = 0
log_error = $(DN_DATA_DIR)/log/alert.log
log_error_verbosity = 2
log_queries_not_using_indexes = OFF
log_slave_updates = 0
log_slow_admin_statements = ON
log_slow_slave_statements = ON
log_throttle_queries_not_using_indexes = 0
long_query_time = 1
loose_ccl_max_waiting_count = 0
loose_ccl_queue_bucket_count = 4
loose_ccl_queue_bucket_size = 64
loose_ccl_wait_timeout = 86400
loose_cluster-id = 1234
loose_cluster-info = 127.0.0.1:14886@1
loose_consensus_auto_leader_transfer = ON
loose_consensus_auto_reset_match_index = ON
loose_consensus_election_timeout = 10000
loose_consensus_io_thread_cnt = 8
loose_consensus_large_trx = ON
loose_consensus_log_cache_size = 536870912
loose_consensus_max_delay_index = 10000
loose_consensus_max_log_size = 20971520
loose_consensus_max_packet_size = 131072
loose_consensus_prefetch_cache_size = 268435456
loose_consensus_worker_thread_cnt = 8
loose_galaxyx_port = 32886
loose_implicit_primary_key = 1
loose_information_schema_stats_expiry = 86400
loose_innodb_buffer_pool_in_core_file = OFF
loose_innodb_commit_cleanout_max_rows = 9999999999
loose_innodb_doublewrite_pages = 64
loose_innodb_lizard_stat_enabled = OFF
loose_innodb_log_compressed_pages = ON
loose_innodb_log_optimize_ddl = OFF
loose_innodb_log_write_ahead_size = 4096
loose_innodb_multi_blocks_enabled = ON
loose_innodb_numa_interleave = OFF
loose_innodb_parallel_read_threads = 1
loose_innodb_undo_retention = 1800
loose_innodb_undo_space_reserved_size = 1024
loose_innodb_undo_space_supremum_size = 102400
loose_internal_tmp_mem_storage_engine = TempTable
loose_new_rpc = ON
loose_optimizer_switch = index_merge=on,index_merge_union=on,index_merge_sort_union=on,index_merge_intersection=on,engine_condition_pushdown=on,index_condition_pushdown=on,mrr=on,mrr_cost_based=on,block_nested_loop=on,batched_key_access=off,materialization=on,semijoin=on,loosescan=on,firstmatch=on,subquery_materialization_cost_based=on,use_index_extensions=on
loose_optimizer_trace = enabled=off,one_line=off
loose_optimizer_trace_features = greedy_search=on,range_optimizer=on,dynamic_range=on,repeated_subselect=on
loose_performance-schema_instrument = 'wait/lock/metadata/sql/mdl=ON'
loose_performance_point_lock_rwlock_enabled = ON
loose_performance_schema-instrument = 'memory/%%=COUNTED'
loose_performance_schema_accounts_size = 10000
loose_performance_schema_consumer_events_stages_current = ON
loose_performance_schema_consumer_events_stages_history = ON
loose_performance_schema_consumer_events_stages_history_long = ON
loose_performance_schema_consumer_events_statements_current = OFF
loose_performance_schema_consumer_events_statements_history = OFF
loose_performance_schema_consumer_events_statements_history_long = OFF
loose_performance_schema_consumer_events_transactions_current = OFF
loose_performance_schema_consumer_events_transactions_history = OFF
loose_performance_schema_consumer_events_transactions_history_long = OFF
loose_performance_schema_consumer_events_waits_current = OFF
loose_performance_schema_consumer_events_waits_history = OFF
loose_performance_schema_consumer_events_waits_history_long = OFF
loose_performance_schema_consumer_global_instrumentation = OFF
loose_performance_schema_consumer_statements_digest = OFF
loose_performance_schema_consumer_thread_instrumentation = OFF
loose_performance_schema_digests_size = 10000
loose_performance_schema_error_size = 0
loose_performance_schema_events_stages_history_long_size = 0
loose_performance_schema_events_stages_history_size = 0
loose_performance_schema_events_statements_history_long_size = 0
loose_performance_schema_events_statements_history_size = 0
loose_performance_schema_events_transactions_history_long_size = 0
loose_performance_schema_events_transactions_history_size = 0
loose_performance_schema_events_waits_history_long_size = 0
loose_performance_schema_events_waits_history_size = 0
loose_performance_schema_hosts_size = 10000
loose_performance_schema_instrument = '%%=OFF'
loose_performance_schema_max_cond_classes = 0
loose_performance_schema_max_cond_instances = 10000
loose_performance_schema_max_digest_length = 0
loose_performance_schema_max_digest_sample_age = 0
loose_performance_schema_max_file_classes = 0
loose_performance_schema_max_file_handles = 0
loose_performance_schema_max_file_instances = 1000
loose_performance_schema_max_index_stat = 10000
loose_performance_schema_max_memory_classes = 0
loose_performance_schema_max_metadata_locks = 10000
loose_performance_schema_max_mutex_classes = 0
loose_performance_schema_max_mutex_instances = 10000
loose_performance_schema_max_prepared_statements_instances = 1000
loose_performance_schema_max_program_instances = 10000
loose_performance_schema_max_rwlock_classes = 0
loose_performance_schema_max_rwlock_instances = 10000
loose_performance_schema_max_socket_classes = 0
loose_performance_schema_max_socket_instances = 1000
loose_performance_schema_max_sql_text_length = 0
loose_performance_schema_max_stage_classes = 0
loose_performance_schema_max_statement_classes = 0
loose_performance_schema_max_statement_stack = 1
loose_performance_schema_max_table_handles = 10000
loose_performance_schema_max_table_instances = 1000
loose_performance_schema_max_table_lock_stat = 10000
loose_performance_schema_max_thread_classes = 0
loose_performance_schema_max_thread_instances = 10000
loose_performance_schema_session_connect_attrs_size = 0
loose_performance_schema_setup_actors_size = 10000
loose_performance_schema_setup_objects_size = 10000
loose_performance_schema_users_size = 10000
loose_persist_binlog_to_redo = OFF
loose_persist_binlog_to_redo_size_limit = 1048576
loose_rds_audit_log_buffer_size = 16777216
loose_rds_audit_log_enabled = OFF
loose_rds_audit_log_event_buffer_size = 8192
loose_rds_audit_log_row_limit = 100000
loose_rds_audit_log_version = MYSQL_V1
loose_recovery_apply_binlog = OFF
loose_replica_read_timeout = 3000
loose_rpc_port = 34886
loose_session_track_system_variables = "*"
loose_session_track_transaction_info = OFF
loose_slave_parallel_workers = 32
low_priority_updates = 0
lower_case_table_names = 1
master_info_file = $(DN_DATA_DIR)/mysql/master.info
master_info_repository = TABLE
master_verify_checksum = OFF
max_allowed_packet = 1073741824
max_binlog_cache_size = 18446744073709551615
max_binlog_stmt_cache_size = 18446744073709551615
max_connect_errors = 65536
max_connections = 5532
max_error_count = 1024
max_execution_time = 0
max_heap_table_size = 67108864
max_join_size = 18446744073709551615
max_length_for_sort_data = 4096
max_points_in_geometry = 65536
max_prepared_stmt_count = 16382
max_seeks_for_key = 18446744073709551615
max_sort_length = 1024
max_sp_recursion_depth = 0
max_user_connections = 5000
max_write_lock_count = 102400
min_examined_row_limit = 0
myisam_sort_buffer_size = 262144
mysql_native_password_proxy_users = OFF
net_buffer_length = 16384
net_read_timeout = 30
net_retry_count = 10
net_write_timeout = 60
ngram_token_size = 2
open_files_limit = 65535
opt_indexstat = ON
opt_tablestat = ON
optimizer_prune_level = 1
optimizer_search_depth = 62
optimizer_trace_limit = 1
optimizer_trace_max_mem_size = 1048576
optimizer_trace_offset = -1
performance_schema = ON
port = 4886
preload_buffer_size = 32768
query_alloc_block_size = 8192
query_prealloc_size = 8192
range_alloc_block_size = 4096
range_optimizer_max_mem_size = 8388608
read_rnd_buffer_size = 442368
relay_log = $(DN_DATA_DIR)/mysql/slave-relay.log
relay_log_index = $(DN_DATA_DIR)/mysql/slave-relay-log.index
relay_log_info_file = $(DN_DATA_DIR)/mysql/slave-relay-log.info
relay_log_info_repository = TABLE
relay_log_purge = OFF
relay_log_recovery = OFF
replicate_same_server_id = OFF
loose_rotate_log_table_last_name =
server_id = 1234
session_track_gtids = OFF
session_track_schema = ON
session_track_state_change = OFF
sha256_password_proxy_users = OFF
show_old_temporals = OFF
skip_slave_start = OFF
skip_ssl = ON
slave_exec_mode = strict
slave_load_tmpdir = $(DN_DATA_DIR)/tmp
slave_net_timeout = 4
slave_parallel_type = LOGICAL_CLOCK
slave_pending_jobs_size_max = 1073741824
slave_sql_verify_checksum = OFF
slave_type_conversions =
slow_launch_time = 2
slow_query_log = OFF
slow_query_log_file = $(DN_DATA_DIR)/mysql/slow_query.log
socket = $(DN_DATA_DIR)/run/mysql.sock
sort_buffer_size = 868352
sql_mode = NO_ENGINE_SUBSTITUTION
stored_program_cache = 256
sync_binlog = 1
sync_master_info = 10000
sync_relay_log = 1
sync_relay_log_info = 10000
table_open_cache_instances = 16
temptable_max_ram = 1073741824
thread_cache_size = 100
thread_stack = 262144
tls_version = TLSv1,TLSv1.1,TLSv1.2
tmp_table_size = 2097152
tmpdir = $(DN_DATA_DIR)/tmp
transaction_alloc_block_size = 8192
transaction_isolation = REPEATABLE-READ
transaction_prealloc_size = 4096
transaction_write_set_extraction = XXHASH64
updatable_views_with_limit = YES
wait_timeout = 28800

[mysqld_safe]
pid_file = $(DN_DATA_DIR)/run/mysql.pid
endef
export MY_CNF

define VERSION_PATCH
diff --git a/VERSION b/MYSQL_VERSION
similarity index 100%
rename from VERSION
rename to MYSQL_VERSION
diff --git a/cmake/mysql_version.cmake b/cmake/mysql_version.cmake
index bed6e9f0..b76b7ba4 100644
--- a/cmake/mysql_version.cmake
+++ b/cmake/mysql_version.cmake
@@ -28,17 +28,17 @@ SET(SHARED_LIB_MAJOR_VERSION "21")
 SET(SHARED_LIB_MINOR_VERSION "1")
 SET(PROTOCOL_VERSION "10")

-# Generate "something" to trigger cmake rerun when VERSION changes
+# Generate "something" to trigger cmake rerun when MYSQL_VERSION changes
 CONFIGURE_FILE(
-  $${CMAKE_SOURCE_DIR}/VERSION
+  $${CMAKE_SOURCE_DIR}/MYSQL_VERSION
   $${CMAKE_BINARY_DIR}/VERSION.dep
 )

-# Read value for a variable from VERSION.
+# Read value for a variable from MYSQL_VERSION.

 MACRO(MYSQL_GET_CONFIG_VALUE keyword var)
  IF(NOT $${var})
-   FILE (STRINGS $${CMAKE_SOURCE_DIR}/VERSION str REGEX "^[ ]*$${keyword}=")
+   FILE (STRINGS $${CMAKE_SOURCE_DIR}/MYSQL_VERSION str REGEX "^[ ]*$${keyword}=")
    IF(str)
      STRING(REPLACE "$${keyword}=" "" str $${str})
      STRING(REGEX REPLACE  "[ ].*" ""  str "$${str}")
@@ -59,7 +59,7 @@ MACRO(GET_MYSQL_VERSION)
   IF(NOT DEFINED MAJOR_VERSION OR
      NOT DEFINED MINOR_VERSION OR
      NOT DEFINED PATCH_VERSION)
-    MESSAGE(FATAL_ERROR "VERSION file cannot be parsed.")
+    MESSAGE(FATAL_ERROR "MYSQL_VERSION file cannot be parsed.")
   ENDIF()

   SET(VERSION
@@ -80,7 +80,7 @@ MACRO(GET_MYSQL_VERSION)
   SET(CPACK_PACKAGE_VERSION_PATCH $${PATCH_VERSION})

   IF(WITH_NDBCLUSTER)
-    # Read MySQL Cluster version values from VERSION, these are optional
+    # Read MySQL Cluster version values from MYSQL_VERSION, these are optional
     # as by default MySQL Cluster is using the MySQL Server version
     MYSQL_GET_CONFIG_VALUE("MYSQL_CLUSTER_VERSION_MAJOR" CLUSTER_MAJOR_VERSION)
     MYSQL_GET_CONFIG_VALUE("MYSQL_CLUSTER_VERSION_MINOR" CLUSTER_MINOR_VERSION)
@@ -89,12 +89,12 @@ MACRO(GET_MYSQL_VERSION)

     # Set MySQL Cluster version same as the MySQL Server version
     # unless a specific MySQL Cluster version has been specified
-    # in the VERSION file. This is the version used when creating
+    # in the MYSQL_VERSION file. This is the version used when creating
     # the cluster package names as well as by all the NDB binaries.
     IF(DEFINED CLUSTER_MAJOR_VERSION AND
        DEFINED CLUSTER_MINOR_VERSION AND
        DEFINED CLUSTER_PATCH_VERSION)
-      # Set MySQL Cluster version to the specific version defined in VERSION
+      # Set MySQL Cluster version to the specific version defined in MYSQL_VERSION
       SET(MYSQL_CLUSTER_VERSION "$${CLUSTER_MAJOR_VERSION}")
       SET(MYSQL_CLUSTER_VERSION
         "$${MYSQL_CLUSTER_VERSION}.$${CLUSTER_MINOR_VERSION}")
@@ -106,7 +106,7 @@ MACRO(GET_MYSQL_VERSION)
       ENDIF()
     ELSE()
       # Set MySQL Cluster version to the same as MySQL Server, possibly
-      # overriding the extra version with value specified in VERSION
+      # overriding the extra version with value specified in MYSQL_VERSION
       # This might be used when MySQL Cluster is still released as DMR
       # while MySQL Server is already GA.
       SET(MYSQL_CLUSTER_VERSION
diff --git a/plugin/galaxy/CMakeLists.txt b/plugin/galaxy/CMakeLists.txt.bak
similarity index 100%
rename from plugin/galaxy/CMakeLists.txt
rename to plugin/galaxy/CMakeLists.txt.bak
diff --git a/plugin/performance_point/CMakeLists.txt b/plugin/performance_point/CMakeLists.txt.bak
similarity index 100%
rename from plugin/performance_point/CMakeLists.txt
rename to plugin/performance_point/CMakeLists.txt.bak
diff --git a/sql/mysqld.cc b/sql/mysqld.cc
index 9fe6d12d..eea38fa7 100644
--- a/sql/mysqld.cc
+++ b/sql/mysqld.cc
@@ -869,6 +869,8 @@ bool opt_large_files = sizeof(my_off_t) > 4;
 static bool opt_autocommit;  ///< for --autocommit command-line option
 static get_opt_arg_source source_autocommit;

+
+bool opt_performance_point_enabled = false;
 /*
   Used with --help for detailed option
 */
diff --git a/sql/package/package_cache.cc b/sql/package/package_cache.cc
index 8a81734e..30ec6a08 100644
--- a/sql/package/package_cache.cc
+++ b/sql/package/package_cache.cc
@@ -76,7 +76,7 @@ static const T *find_package_element(const std::string &schema_name,
   return Package::instance()->lookup_element<T>(schema_name, element_name);
 }
 /* Template instantiation */
-template static const Proc *find_package_element(
+template const Proc *find_package_element(
     const std::string &schema_name, const std::string &element_name);

 /**
endef

export VERSION_PATCH
