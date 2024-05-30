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

echo -e "Deleting removed users..."

if [ -z "$groupId" ]
then
    echo -e "\tError: Group $groupName not found"
    exit 1
fi

(sudo grep ":$groupId::" /etc/passwd) | cut -d: -f1 | while read -r user
do 
    if (! grep -q $user $2)
    then
        echo -e "\tDeleting user $user"
        sudo sed -i "/#$user/d" /etc/exports
        sudo userdel -r $user &> /dev/null
    fi
done
