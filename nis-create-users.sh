#!/bin/bash

if [ $# -ne 1 ]
then
    echo "Usage: $0 <filename>"
    exit 1
fi

if [ ! -r $1 ]
then
    echo "Error: Cannot read file $1"
    exit 1
fi

while IFS=: read -r name pwd dir
do
    if [ -z "$name" ] || [ -z "$pwd" ] || [ -z "$dir" ]
    then
        echo "Error: Invalid line format in $1: $name:$pwd:$dir"
        echo "Valid format is <name>:<password>:<directory>"
        continue
    fi

    echo "Configuring $name:$dir"

    if (id -u $name > /dev/null 2>&1)
    then
        echo "  User $name already exists"        
    else
        echo "  Creating user $name..."
        useradd $name
        echo "$name:$pwd" | chpasswd &> /dev/null
    fi

    home="/home/$name"

    if [ -d $home ]; then
        echo "  Directory $home already exists"
    else
        echo "  Creating directory $home..."
        mkdir -p $home
    fi

    chown $name:$name $home
    chmod 750 $home

    if [ "$(cat /etc/passwd | grep $name | cut -d: -f6)" == "$dir" ]
    then
        echo "  Home directory of $name is already set to $dir"
    else
        echo "  Home directory of $name to $dir..."
        usermod -d $dir $name
    fi

    host="*"
    if (! grep -q "$home" /etc/exports)
    then
        echo "$home $host(rw)" >> /etc/exports
    fi
done < $1

exportfs -a

echo "Updating NIS maps..."
systemctl restart ypserv
make -C /var/yp > /dev/null

echo "Restarting services..."
systemctl restart ypserv
systemctl restart yppasswdd
systemctl restart nfs-server

# TODO: configure the client via SSH to use the NIS server and to restart services
