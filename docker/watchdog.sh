#!/bin/bash

# Copyright 2021 Alibaba Group Holding Limited.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

RUN_PATH=$BUILD_PATH/run

function cn_pid() {
  ps auxf | grep java | grep TddlLauncher | cut -d ' ' -f 1
}

function dn_pid() {
  ps aux | grep mysqld_safe | grep -v "grep" | awk '{print $2}'
}

retry() {
  retry_interval=5
  retry_cnt=0
  retry_limit=10
  succeed=0
  while [ ${retry_cnt} -lt ${retry_limit} ]; do
    if [[ $1 ]]; then
      succeed=1
      return 0
    fi

    echo "Fail to $1, retry..."

    ((retry_cnt++))

    sleep "${retry_interval}"
  done

  if [ ${succeed} -eq 0 ]; then
    echo "$1 failed."
    return 1
  fi
  return 0
}

start_cn() {
    echo "start cn..."
    rm -f $RUN_PATH/polardbx-sql/bin/*.pid
    $RUN_PATH/polardbx-sql/bin/startup.sh -P asdf1234ghjk5678
    echo "cn starts."
}

start_dn() {
    echo "start gms & dn..."
    ($RUN_PATH/polardbx-engine/u01/mysql/bin/mysqld_safe --defaults-file=$BUILD_PATH/run/polardbx-engine/data/my.cnf &)
    if ! retry "mysql -h127.1 -P4886 -uroot -e 'create table if not exists polardbx_meta_db_polardbx.__test_avaliable__(id int)'"; then
      echo "gms and dn start failed."
    fi
    echo "gms and dn are running."
    mysql -h127.1 -P4886 -uroot -e 'drop table if exists polardbx_meta_db_polardbx.__test_avaliable__'
}

while true; do
    pid=$(dn_pid)
    if [ -z "$pid" ]; then
        echo "DN process dead. Try to restart it."
        start_dn
    fi
    pid=$(cn_pid)
    if [ -z "$pid" ]; then
        echo "CN process dead. Try to restart it."
        start_cn
    fi
    sleep 5
done
