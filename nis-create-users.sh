#!/bin/bash
#v2

print_usage() {
    echo "Usage: nis-create-users.sh --users <users> --hosts <hosts>"
    exit 1
}

while [ $# -gt 0 ]
do
    key="$1"
    case $key in
        --users)
            USERS="$2"
            shift
            ;;
        --hosts)
            HOSTS="$2"
            shift
            ;;
        *)
            print_usage
            ;;
    esac
    shift
done

if [ -z "$USERS" ] || [ -z "$HOSTS" ]
then
    print_usage
fi

if [ ! -f $USERS ]
then
    echo "Error: File $USERS not found"
    exit 1
fi

if [ ! -f $HOSTS ]
then
    echo "Error: File $HOSTS not found"
    exit 1
fi

echo $USERS
echo $HOSTS

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

    while IFS= read -r host
    do
        if [ -z "$host" ]
        then
            continue
        fi

        echo "  Configuring $name:$home for $host..."

        if ! grep -q "$home" /etc/exports
        then
            echo "$home $host(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
        fi
    done < $HOSTS
done < $USERS

exportfs -a

echo "Updating NIS maps..."
systemctl restart ypserv
make -C /var/yp > /dev/null

echo "Restarting services..."
systemctl restart ypserv
systemctl restart yppasswdd
systemctl restart nfs-server

# TODO: configure the client via SSH to configure the NFS share and add a symbolic link to the home directory
