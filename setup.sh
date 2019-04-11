#/bin/bash

set -e

if pvs | grep '/dev/sd[cd]'
then
    echo "HDD already used as LVM PV"; exit 1;
done

if grep 'sd[cd]' /proc/mdstat
then
    echo "HDD already used as MD"; exit 1;
done

for sd in /dev/sd{a,b,c,d}
do
    fdisk -l $sd | grep -q "Disklabel type: gpt" || { echo "$sd disklabel type is not GPT"; exit 1; }
done

lvextend ubuntu-vg/ubuntu-lv --extents +100%FREE
resize2fs /dev/ubuntu-vg/ubuntu-lv

pvcreate /dev/sdb1 -y
vgcreate ssd-vg /dev/sdb1
lvcreate ssd-vg --name ssd-lv --extents 100%VG

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
