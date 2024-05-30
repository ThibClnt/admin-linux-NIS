
echo -e "Resetting NIS..."

cat /etc/exports | grep "(rw," | cut -d"#" -f2 | while read -r user
do
    sudo userdel $user
    echo -e "\tDeleted - $user"
done
sudo userdel nis-admin
echo -e "\tDeleted - nis-admin"
sudo groupdel nis-managed
echo -e "\tDeleted - group nis-managed"

cat /etc/exports | grep "(rw," | cut -d" " -f1 | while read -r dir
do
    sudo rm -rf $dir
    echo -e "\tDeleted - $dir"
done

echo -e "\n" | sudo tee /etc/exports
echo -e "\tEmptied - /etc/exports"



echo -e "\nUpdating NIS maps..."
sudo exportfs -a
sudo systemctl restart ypserv
sudo make -C /var/yp > /dev/null

echo -e "\nRestarting services..."
sudo systemctl restart ypserv
sudo systemctl restart yppasswdd
sudo systemctl restart nfs-server



echo -e "NIS reset complete."
