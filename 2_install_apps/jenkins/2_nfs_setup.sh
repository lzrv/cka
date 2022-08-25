
# 1/ Setup NFS server
sudo apt update && sudo apt install nfs-kernel-server

# 2/ Verify the enabled NFS versions
sudo cat /proc/fs/nfsd/versions

# 3/ Create NFS root dir and kubedata dir:
sudo mkdir -p /srv/nfs4/backups
sudo mount --bind /kubedata /srv/nfs4/kubedata/

# 4/ Export the directory
# sudo vi /etc/exports
# 
# /srv/nfs4/kubedata 172.31.103.173(rw,sync,no_subtree_check)
# 172.31.96.249(rw,sync,no_subtree_check) 172.31.101.91(rw,sync,no_subtree_check)

sudo exportfs -ar
# view active exports
sudo exportfs -v

# 5/ Configure clients
sudo apt update && sudo apt install nfs-common
sudo mkdir /kubedata
sudo chmod 777 /kubedata
sudo mount -t nfs -o vers=4 172.31.103.173:/srv/nfs4/kubedata /kubedata/
