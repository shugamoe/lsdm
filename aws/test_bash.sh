#!/bin/bash

while getopts u:s: option
do
    case "${option}" 
    in
    u) USER=${OPTARG};;
    s) SLAVES=${OPTARG};;
    esac
done

echo $USER
echo $SLAVES
