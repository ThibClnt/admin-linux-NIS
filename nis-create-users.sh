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
        sudo useradd $name
        echo "$name:$pwd" | sudo chpasswd &> /dev/null
    fi

    if [ -d $dir ]; then
        echo "  Directory $dir already exists"
    else
        echo "  Creating directory $dir..."
        sudo mkdir -p $dir
    fi

    sudo chown $name:$name $dir
    sudo chmod 750 $dir

    if [ "$(cat /etc/passwd | grep $name | cut -d: -f6)" == "$dir" ]
    then
        echo "  Home directory of $name is already set to $dir"
    else
        echo "  Home directory of $name to $dir..."
        sudo usermod -d $dir $name
    fi

    while IFS= read -r host
    do
        if [ -z "$host" ]
        then
            continue
        fi

        echo "  Configuring $name:$dir for $host..."

        if ! grep -q "$dir" /etc/exports
        then
            echo "$dir $host(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports > /dev/null
        fi
    done < $HOSTS
done < $USERS

sudo exportfs -a

echo "Updating NIS maps..."
sudo systemctl restart ypserv
sudo make -C /var/yp > /dev/null

echo "Restarting services..."
sudo systemctl restart ypserv
sudo systemctl restart yppasswdd
sudo systemctl restart nfs-server

# TODO: configure the client via SSH to configure the NFS share and add a symbolic link to the home directory
passwd="nis-admin"
while IFS= read -r host
do
    if [ -z "$host" ]
    then
        continue
    fi

    echo "Configuring client $host..."
    ssh "nis-admin@$host" "echo $passwd | sudo -S systemctl restart ypbind >/dev/null 2>&1" < /dev/null

    while IFS=: read -r name pwd dir
    do
        echo "  Configuring $name:$dir for $host..."
        ssh "nis-admin@$host" "echo  $passwd | sudo -S mkdir -p $dir >/dev/null 2>&1" < /dev/null

        # Store the remote command in a variable for readability
        MNT_CONFIG_CMD="
        if ! grep -q \"\$(ypwhich):$dir\" /etc/fstab; then
            echo \"\$(ypwhich):$dir $dir nfs default 0 2\" | sudo tee -a /etc/fstab
        fi
        "

        ssh nis-admin@"$host" "echo $passwd | sudo -S bash -c '$MNT_CONFIG_CMD' >/dev/null 2>&1" < /dev/null
    done < $USERS
    
    ssh "nis-admin@$host" "echo  $passwd | sudo -S mount -a >/dev/null 2>&1" < /dev/null
done < $HOSTS
