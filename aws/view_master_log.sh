#!/bin/bash

export CID=`aws emr list-clusters --no-verify-ssl | head -10 | grep "Id" | awk -F"\"" '{print $4}'`

export INSTANCE_ID=`grep -rl 'IS_MASTER=true' logs/$CID | awk -F"/" '{print $4}'`

nvim logs/$CID/node/$INSTANCE_ID\bootstrap-actions/1/stderr
