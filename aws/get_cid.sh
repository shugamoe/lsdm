#!/bin/bash

export CID=`aws emr list-clusters --no-verify-ssl | head -10 | grep "Id" | awk -F"\"" '{print $4}'`
