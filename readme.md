
# Projet Admin Linux


## Configuration initiale

### Client

Configurer le client NFS / NIS

useradd nis-admin --create-home
Serveur :
    ssh-keygen -t ed25519
    ssh-copy-id -i ~/.ssh/id_ed25519.pub nis-admin@[IP CLIENT]



Script principal : ./nis-manager.sh  --users nis-users --hosts nis-clients

Script de reset : ./src/nis-reset.sh
