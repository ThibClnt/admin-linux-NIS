#!/bin/bash
#!/bin/bash
# NAME
#       ./source/nis-create-users.sh
#
# DESCRIPTION
#       Create or refresh users
#
# PARAMETERS
#       arg1: group name (nis-managed)
#       arg2: users config file path
#       arg3: hosts config file path 
#       arg4: admin user name
#


NIS_GROUP=$1
USERS=$2
HOSTS=$3
ADMIN_PWD=$4

# Create or refresh users
while IFS=: read -r name pwd dir
do
    if [ -z "$name" ] || [ -z "$pwd" ] || [ -z "$dir" ]
    then
        echo "Error: Invalid line format in $USERS: $name:$pwd:$dir"
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
        echo -e "\tCreated - dir $dir"
    fi
    sudo chown $name:$NIS_GROUP $dir
    sudo chmod 700 $dir
    echo -e "\tSet - permissions for $dir"
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

while IFS= read -r host
do
    if [ -z "$host" ]
    then
        continue
    fi

    echo "Configuring client $host..."
    ssh "nis-admin@$host" "echo $ADMIN_PWD | sudo -S systemctl restart ypbind >/dev/null 2>&1" < /dev/null

    while IFS=: read -r name pwd dir
    do
        echo "  Configuring $name:$dir for $host..."
        ssh "nis-admin@$host" "echo  $ADMIN_PWD | sudo -S mkdir -p $dir >/dev/null 2>&1" < /dev/null

        # Store the remote command in a variable for readability
        MNT_CONFIG_CMD="
        if ! grep -q \"\$(ypwhich):$dir\" /etc/fstab; then
            echo \"\$(ypwhich):$dir $dir nfs default 0 2\" | sudo tee -a /etc/fstab
        fi
        "

        ssh nis-admin@"$host" "echo $ADMIN_PWD | sudo -S bash -c '$MNT_CONFIG_CMD' >/dev/null 2>&1" < /dev/null
    done < $USERS
    
    ssh "nis-admin@$host" "echo  $ADMIN_PWD | sudo -S mount -a >/dev/null 2>&1" < /dev/null
done < $HOSTS
