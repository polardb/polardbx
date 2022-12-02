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

GALAXYSQL_HOME=/home/admin/polardb-x/galaxysql
GALAXYCDC_HOME=/home/admin/polardb-x/galaxycdc/polardbx-binlog.standalone

if [ x"$mode" = "x" ]; then
    mode="play"
fi

function cn_pid() {
  ps auxf | grep java | grep TddlLauncher | cut -d ' ' -f 1
}

function cdc_pid() {
  ps auxf | grep java | grep DaemonBootstrap | cut -d ' ' -f 1
}

function dn_pid() {
  ps aux | grep mysqld | grep -v "grep" | awk '{print $2}'
}

function get_pid() {
    if [ x"$mode" = x"play" ]; then
        cn_pid
    elif [ x"$mode" = x"dev" ]; then
        dn_pid
    else
        echo "mode=$mode does not support yet."
        echo ""
    fi
}

function stop_all() {
  /home/admin/polardb-x/bin/polardb-x.sh stop
  rm -f $GALAXYSQL_HOME/bin/*.pid
  rm -f $GALAXYCDC_HOME/bin/*.pid
}

function init() {
    if [ ! -d "/home/admin/polardb-x/galaxyengine/data" ]; then
        echo "start initializing..."
        /home/admin/polardb-x/bin/polardb-x.sh init
    fi
}

function start_polardb_x() {
  echo "start polardb-x"

  init
  /home/admin/polardb-x/bin/polardb-x.sh start
}

function start_gms_and_dn() {
  echo "start gms and dn"

  init
  /home/admin/polardb-x/galaxyengine/u01/mysql/bin/mysqld --defaults-file=/home/admin/polardb-x/galaxyengine/my.cnf -D
}

function start_process() {
  echo "start with mode=$mode"
  if [ x"$mode" = x"play" ]; then
      start_polardb_x
  elif [ x"$mode" = x"dev" ]; then
      start_gms_and_dn
  else
      echo "mode=$mode does not support yet."
  fi
}

last_pid=0
function report_pid() {
  pid=$(get_pid)
  if [ -z "$pid" ]; then
    echo "Process dead. Exit."
    last_pid=0
    return 1
  else
    if [[ $pid -ne $last_pid ]]; then
      echo "Process alive: " "$pid"
    fi
    last_pid=pid
  fi
  return 0
}

function watch() {
  while report_pid; do
    sleep 5
  done
}

function start() {
  # Start
  stop_all
  start_process
}

# Retry start and watch

retry_interval=5
retry_cnt=0
retry_limit=10
if [[ "$#" -ge 1 ]]; then
  retry_limit=$1
fi

while [[ $retry_cnt -lt $retry_limit ]]; do
  start
  watch

  ((retry_cnt++))

  if [[ $retry_cnt -lt $retry_limit ]]; then
    sleep $retry_interval
  fi
done

# Abort.
exit 1
