#!/bin/bash
# NAME
#       ./source/nis-delete-users.sh
#
# DESCRIPTION
#       Create the technical user "nis-admin"
#
# PARAMETERS
#       arg1: group name
#       arg2: relative file that contains the config
#

groupName=$1
groupId=$(getent group $groupName | cut -d: -f3)

echo -e "\nDeleting removed users..."

if [ -z "$groupId" ]
then
    echo -e "\tError: Group $groupName not found"
    exit 1
fi

mkdir -p ./nis-state

echo -e "" > ./nis-state/deleted-users.tmp
(sudo grep ":$groupId::" /etc/passwd) | cut -d: -f1 | while read -r user
do 
    if (! grep -q $user $2)
    then
        sudo userdel -r $user &> /dev/null
        echo -e "\tDelete - user $user"
        sudo sed -i "/#$user/d" /etc/exports
        echo -e "\tDelete - /etc/exports"
        echo -e "$user" >> ./nis-state/deleted-users.tmp
    fi
done
