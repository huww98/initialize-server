#!/bin/bash

# Set Timezone
# Format and mount all disks as follow:
# NAME                      SIZE TYPE  MOUNTPOINT
# sda                     223.6G disk
# ├─sda1                      1M part
# ├─sda2                      1G part  /boot
# └─sda3                  222.6G part
#   └─ubuntu-vg/ubuntu-lv 222.6G lvm   /
# sdb                     953.9G disk
# └─sdb1                  953.9G part
#   └─ssd-vg/ssd-lv       953.9G lvm   /mnt/ssd
# sdc                       5.5T disk
# └─sdc1                    5.5T part
#   └─md/hdd               10.9T raid0
#     ├─hdd-vg/dataset-lv     3T lvm   /mnt/dataset
#     └─hdd-vg/home-lv      7.9T lvm   /home
# sdd                       5.5T disk
# └─sdd1                    5.5T part
#   └─md/hdd               10.9T raid0
#     ├─hdd-vg/dataset-lv     3T lvm   /mnt/dataset
#     └─hdd-vg/home-lv      7.9T lvm   /home
#
# May need some manual cleanup

set -e

if pvs | grep '/dev/sd[cd]'
then
    echo "HDD already used as LVM PV"; exit 1;
fi

for sd in /dev/sd{a,b,c,d}
do
    fdisk -l $sd | grep -q "Disklabel type: gpt" || { echo "$sd disklabel type is not GPT"; exit 1; }
done

sed --in-place "s/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/" /etc/apt/sources.list
apt-get update
apt-get upgrade

timedatectl set-timezone Asia/Shanghai

lvextend ubuntu-vg/ubuntu-lv --extents +100%FREE
resize2fs /dev/ubuntu-vg/ubuntu-lv

sfdisk --part-type /dev/sdb 1 E6D6D379-F507-44C2-A23C-238F2A3DF928 # Linux LVM
pvcreate /dev/sdb1 -y
vgcreate ssd-vg /dev/sdb1
lvcreate ssd-vg --name ssd-lv --extents 100%VG

mdadm --stop /dev/md0 || true
for sd in /dev/sd{c,d}
do
    sfdisk --part-type $sd 1 A19D880F-05FC-4D3B-A006-743F0F84911E # Linux RAID
done
mdadm --stop /dev/md0 || true
mdadm --create /dev/md/hdd --level raid0 --raid-devices=2 /dev/sdc1 /dev/sdd1
pvcreate /dev/md/hdd
vgcreate hdd-vg /dev/md/hdd
lvcreate hdd-vg --name dataset-lv --size 3T
lvcreate hdd-vg --name home-lv --extents 100%FREE

mkfs.ext4 /dev/ssd-vg/ssd-lv
mkfs.ext4 /dev/hdd-vg/home-lv
mkfs.xfs /dev/hdd-vg/dataset-lv

cat > /etc/fstab << EOF
UUID=$(blkid /dev/ubuntu-vg/ubuntu-lv -o value | head -n 1) / ext4 defaults 0 1
UUID=$(blkid /dev/sda2 -o value | head -n 1) /boot ext4 defaults 0 2
/swap.img       none    swap    sw      0 0
UUID=$(blkid /dev/ssd-vg/ssd-lv -o value | head -n 1) /mnt/ssd ext4 defaults 0 2
UUID=$(blkid /dev/hdd-vg/home-lv -o value | head -n 1) /home ext4 defaults 0 2
UUID=$(blkid /dev/hdd-vg/dataset-lv -o value | head -n 1) /mnt/dataset xfs defaults 0 2
EOF

mkdir -p /mnt/ssd
mkdir -p /mnt/dataset
mv /home /homeold
mkdir -p /home
mount -a
mv /homeold/* /home
rm -r /homeold
