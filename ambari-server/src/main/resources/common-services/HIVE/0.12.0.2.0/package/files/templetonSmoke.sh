#!/usr/bin/env bash
#
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#

export ttonhost=$1
export smoke_test_user=$2
export templeton_port=$3
export ttonTestScript=$4
export smoke_user_keytab=$5
export security_enabled=$6
export kinit_path_local=$7
export smokeuser_principal=$8
export ttonurl="http://${ttonhost}:${templeton_port}/templeton/v1"

if [[ $security_enabled == "true" ]]; then
  kinitcmd="${kinit_path_local}  -kt ${smoke_user_keytab} ${smokeuser_principal}; "
else
  kinitcmd=""
fi

export no_proxy=$ttonhost
cmd="${kinitcmd}curl --negotiate -u : -s -w 'http_code <%{http_code}>'    $ttonurl/status 2>&1"
retVal=`/var/lib/ambari-agent/ambari-sudo.sh su ${smoke_test_user} -s /bin/bash - -c "$cmd"`
httpExitCode=`echo $retVal |sed 's/.*http_code <\([0-9]*\)>.*/\1/'`

if [[ "$httpExitCode" -ne "200" ]] ; then
  echo "Templeton Smoke Test (status cmd): Failed. : $retVal"
  export TEMPLETON_EXIT_CODE=1
  exit 1
fi

exit 0

#try hcat ddl command
echo "user.name=${smoke_test_user}&exec=show databases;" /tmp/show_db.post.txt
cmd="${kinitcmd}curl --negotiate -u : -s -w 'http_code <%{http_code}>' -d  \@${destdir}/show_db.post.txt  $ttonurl/ddl 2>&1"
retVal=`/var/lib/ambari-agent/ambari-sudo.sh su ${smoke_test_user} -s /bin/bash - -c "$cmd"`
httpExitCode=`echo $retVal |sed 's/.*http_code <\([0-9]*\)>.*/\1/'`

if [[ "$httpExitCode" -ne "200" ]] ; then
  echo "Templeton Smoke Test (ddl cmd): Failed. : $retVal"
  export TEMPLETON_EXIT_CODE=1
  exit  1
fi

# NOT SURE?? SUHAS
if [[ $security_enabled == "true" ]]; then
  echo "Templeton Pig Smoke Tests not run in secure mode"
  exit 0
fi

#try pig query
ttonTestScript="idtest.${outname}.pig"

#create, copy post args file
echo -n "user.name=${smoke_test_user}&file=/tmp/$ttonTestScript" > /tmp/pig_post.txt

#submit pig query
cmd="curl -s -w 'http_code <%{http_code}>' -d  \@${destdir}/pig_post.txt  $ttonurl/pig 2>&1"
retVal=`/var/lib/ambari-agent/ambari-sudo.sh su ${smoke_test_user} -s /bin/bash - -c "$cmd"`
httpExitCode=`echo $retVal |sed 's/.*http_code <\([0-9]*\)>.*/\1/'`
if [[ "$httpExitCode" -ne "200" ]] ; then
  echo "Templeton Smoke Test (pig cmd): Failed. : $retVal"
  export TEMPLETON_EXIT_CODE=1
  exit 1
fi

exit 0
