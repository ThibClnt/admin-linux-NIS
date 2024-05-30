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

# Configure the technical user
source ./src/nis-admin.sh
# Delete removed users
source ./src/nis-delete-users.sh $NIS_GROUP $USERS
# Create or refresh users
while IFS=: read -r name pwd dir
do
    if [ -z "$name" ] || [ -z "$pwd" ] || [ -z "$dir" ]
    then
        echo "Error: Invalid line format in $1: $name:$pwd:$dir"
        echo "Valid format is <name>:<password>:<directory>"
        continue
    fi

    echo -e "\nConfiguring $name:$dir"

    # Create the user
    if (id -u $name > /dev/null 2>&1)
    then
        echo -e "\tOK - user"
    else 
        sudo useradd $name -g $NIS_GROUP
        echo -e "\tCreated - user $name"
    fi
    # Update the password
    echo "$name:$pwd" | sudo chpasswd &> /dev/null
    echo -e "\tSet - password"
    # Create the home directory
    if [ -d $dir ]
    then
        echo -e "\tOK - dir"
    else
        sudo mkdir -p $dir
        sudo chown $name:$NIS_GROUP $dir
        sudo chmod 700 $dir
        echo -e "\tCreated - dir $dir"
    fi
    # Set the home directory
    if [ "$(cat /etc/passwd | grep $name | cut -d: -f6)" == "$dir" ]
    then
        echo -e "\tOK - ~$name = $dir"
    else
        sudo usermod -d $dir $name
        echo -e "\tSet - ~$name = $dir"
    fi

    while IFS= read -r host
    do
        if [ -z "$host" ]
        then
            continue
        fi

        if (grep -q "$dir" /etc/exports)
        then
            echo -e "\tOK - /etc/exports"
        else
            echo -e "\tConfiguring $name:$dir for $host..."
            echo "$dir $host(rw,sync,no_subtree_check,no_root_squash) #$name" | sudo tee -a /etc/exports
        fi
    done < $HOSTS
done < $USERS

sudo exportfs -a

echo -e "\nUpdating NIS maps..."
sudo systemctl restart ypserv
sudo make -C /var/yp > /dev/null

echo -e "\nRestarting services..."
sudo systemctl restart ypserv
sudo systemctl restart yppasswdd
sudo systemctl restart nfs-server

# TODO: configure the client via SSH to configure the NFS share and add a symbolic link to the home directory
