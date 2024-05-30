
print_usage() {
    echo "Usage: nis-manager.sh --users <users> --hosts <hosts>"
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
# Exports: $ADMIN_USR, $NIS_GROUP
source ./src/nis-admin.sh

# Delete removed users
source ./src/nis-delete-users.sh $NIS_GROUP $USERS

# Create or refresh users
source ./src/nis-create-users.sh $NIS_GROUP $USERS $HOSTS $ADMIN_USR
