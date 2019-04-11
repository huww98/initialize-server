#/bin/bash

set -e

if pvs | grep '/dev/sd[cd]'
then
    echo "HDD already used as LVM PV"; exit 1;
fi

if grep 'sd[cd]' /proc/mdstat
then
    echo "HDD already used as MD"; exit 1;
fi

for sd in /dev/sd{a,b,c,d}
do
    fdisk -l $sd | grep -q "Disklabel type: gpt" || { echo "$sd disklabel type is not GPT"; exit 1; }
done

timedatectl set-timezone Asia/Shanghai

lvextend ubuntu-vg/ubuntu-lv --extents +100%FREE
resize2fs /dev/ubuntu-vg/ubuntu-lv

sfdisk --part-type /dev/sdb 1 E6D6D379-F507-44C2-A23C-238F2A3DF928 # Linux LVM
pvcreate /dev/sdb1 -y
vgcreate ssd-vg /dev/sdb1
lvcreate ssd-vg --name ssd-lv --extents 100%VG

for sd in /dev/sd{c,d}
do
    sfdisk --part-type $sd 1 A19D880F-05FC-4D3B-A006-743F0F84911E # Linux RAID
done
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
