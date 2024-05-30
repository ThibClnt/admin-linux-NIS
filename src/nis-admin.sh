#!/bin/bash
# NAME
#       source ./src/nis-admin
#
# DESCRIPTION
#       Create the technical user "nis-admin"
#
# EXPORTS
#       ADMIN_USR technical user name 
#       ADMIN_PWD technical user password


echo -e "Configuring technical user (nis-admin)..."

export ADMIN_USR="nis-admin"
export ADMIN_PWD="nis-password"
export NIS_GROUP="nis-managed"

if (id -u $ADMIN_USR > /dev/null 2>&1)
then
    echo -e "\tOK - user $ADMIN_USR";
else
    sudo useradd $ADMIN_USR -p $ADMIN_PWD -M
    echo -e "\tCreated new user $ADMIN_USR";
fi

if (getent group $NIS_GROUP > /dev/null 2>&1)
then
    echo -e "\tOK - group $NIS_GROUP";
else
    sudo groupadd $NIS_GROUP
    echo -e "\tCreated new group $NIS_GROUP";
fi

