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
export NIS_GROUP="nis-managed"


# CONFIGURATION CLIENT NÉCESSAIRE
#   Client : 
#       useradd nis-admin --create-home
#   Serveur :
#       ssh-keygen -t ed25519
#       ssh-copy-id -i ~/.ssh/id_ed25519.pub nis-admin@[IP CLIENT]

#export ADMIN_PWD="nis-password"
# if (id -u $ADMIN_USR > /dev/null 2>&1)
# then
#     echo -e "\tOK - user $ADMIN_USR";
# else
#     sudo useradd $ADMIN_USR -M
#     echo "$ADMIN_USR:$ADMIN_PWD" | sudo chpasswd &> /dev/null
#     echo -e "\tCreated new user $ADMIN_USR";
# fi

if (getent group $NIS_GROUP > /dev/null 2>&1)
then
    echo -e "\tOK - group $NIS_GROUP";
else
    sudo groupadd $NIS_GROUP
    echo -e "\tCreated new group $NIS_GROUP";
fi

