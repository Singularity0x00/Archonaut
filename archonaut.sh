#/bin/bash
printf '\033c'
echo -e " \033[0;31m░█▀█░█▀▄░█▀▀░█░█░█▀█░█▀█░█▀█░█░█░▀█▀ \n ░█▀█░█▀▄░█░░░█▀█░█░█░█░█░█▀█░█░█░░█░ \n ░▀░▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░░▀░"
echo -e "\033[1m       ARCHISO to ARCH_RICED_UP \033[0m"

echo -e "Full ARCH install OR Just Rice?? \n 1:Full_install \n 2:Rice \n Enter Choice number \033[0;31m(1/2): \033[0m"
read choice
if [[ $choice = "2" ]] ; then 
	sed '5,/^##Ricing_up$/d' `basename $0` > $HOME/Rice.sh 
	chmod +x $HOME/Rice.sh
	/bin/bash $HOME/Rice.sh
fi

#INITIAL_SETUP
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
reflector --latest 25 --sort rate --save /etc/pacman.d/mirrorlist
pacman --noconfirm -Sy archlinux-keyring
loadkeys us
timedatectl set-ntp true
printf '\033c'

##partitioning
lsblk
read -p "Enter the drive: " drive 
cfdisk $drive 

read -p "Enter the linux partition: " partition
read -p "Choose filesystem, default ext4 (ext4/btrfs): " fisy 

if [[ $fisy = btrfs ]] ; then 
	mkfs.btrfs $partition
else
	mkfs.ext4 $partition
fi

read -p "Create EFI Partition? (y/n) " response
if [[ $response = [y,Y] ]] ; then
	read -p "Enter EFI Partition:" efip 
        mkfs.vfat -F 32 $efip
fi

read -p "Create Swap Partition? (y/n) " ans 
if [[ $ans = [y,Y] ]] ; then
	read -p "Enter Swap Partition:" swappart 
        mkswap $swappart
fi

echo "Partitioning done; Mounting partitions"

mount $partition /mnt
[[ -f $efip ]] && mount --mkdir $efip /mnt/boot
[[ -f $swappart ]] && swapon $swappart

echo "Mounted"

##BTRFS Specific config
if [[ $(lsblk -o FSTYPE $partition | sed '1d') = btrfs ]] ; then 
	echo "Configuring BTRFS...."	
	btrfs su cr /mnt/@
	btrfs su cr /mnt/@home
	btrfs su cr /mnt/@snapshots
	btrfs su cr /mnt/@var_log
	umount /mnt
	mkdir -p /mnt/{home, .snapshots, var_log}
	mount -o noatime,compress=lzo,space_cache=v2,subvol=@ $partition /mnt
	mount -o noatime,compress=lzo,space_cache=v2,subvol=@home $partition /mnt/home
	mount -o noatime,compress=lzo,space_cache=v2,subvol=@snapshots $partition /mnt/.snapshots
	mount -o noatime,compress=lzo,space_cache=v2,subvol=@var_log $partition /mnt/var_log
	echo "Done!"
fi

##chroot prep 
pacstrap /mnt base base-devel linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab
sed '5,/^#CHROOT$/d' `basename $0` > /mnt/archonaut2.sh
chmod +x /mnt/archonaut2.sh
arch-chroot /mnt ./archonaut2.sh
exit 

#CHROOT

pacman -S --noconfirm sed 
sed -i "s/^#ParallelDownloads = 5$/ParallelDownloads = 15/" /etc/pacman.conf
echo "ILoveCandy" >> /etc/pacman.conf

ln -sf /usr/share/zoneinfo/Asia/Kolkata /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "ja_JP.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=us" > /etc/vconsole.conf
printf '\033c'

read -p "Enter Hostname: " hostname 
echo $hostname >> /etc/hostname
echo "127.0.0.1       localhost" >> /etc/hosts
echo "::1             localhost" >> /etc/hosts
echo "127.0.1.1       $hostname.localdomain $hostname" >> /etc/hosts
mkinitcpio -P

printf '\033c'
passwd

mount $efip /mnt/boot
bootctl install #systemd-boot

pacman -S --noconfirm fish git wget curl awk grep openssh libssh2 \
     xorg-server xorg-xinit xorg-xkill xorg-xsetroot xorg-xprop \
     noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-joypixels ttf-font-awesome \
     ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-common ttf-space-mono-nerd \  
     sxiv mpv mupdf ffmpeg imagemagick xrandr \
     fzf man-db feh python-pywal xclip flameshot \
     tar zip unzip unrar p7zip brightnessctl  \
     dosfstools ntfs-3g pipewire pipewire-pulse pavucontrol \
     vim neovim rsync neofetch \
     jq aria2 shred \
     dhcpcd networkmanager wpa_supplicant pamixer mpd ncmpcpp \
     xdg-user-dirs libconfig \
     alacritty newsboat awesome ly rofi firefox

printf '\033c'
systemctl enable NetworkManager.service 

echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers
printf '\033c'
read -p "Enter username: " username
useradd -m -G wheel -s /sbin/fish $username
passwd $username

sed '5,/^#POST_INSTALL$/d' archonaut2.sh > /home/$username/archonaut_post_setup.sh 
chown $username:$username /home/$username/archonaut_post_setup.sh  
chmod +x /home/$username/archonaut_post_setup.sh 
su -c /home/$username/archonaut_post_setup.sh -s /bin/bash $username
echo "Installation done, reboot and run archonaut_post_setup.sh"
exit 

#POST_INSTALL

##blackarch_repo
read -p "install blackarch Repo? (y/n); " opt
if [[ $opt = [y,Y] ]] ; then
	echo "installing BlackArch Repo"
	curl -O https://blackarch.org/strap.sh
	echo 5ea40d49ecd14c2e024deecf90605426db97ea0c strap.sh | sha1sum -c
	chmod +x strap.sh
	sudo ./strap.sh
	echo "done && updating"
	sudo pacman -Syu
fi

##AUR_paru
echo "Installing Paru AUR helper..."
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si

paru -S picom-jonaburg-git python-pywalfox
printf '\033c'

##Ricing_up
cd $HOME

echo -e "\033[1mRicing UP!!! \033[0m"
[[ ! -d AwesomeDots/ ]] && git clone https://github.com/HrideshG88/AwesomeDots.git ;
rsync -avxP AwesomeDots/config/ $HOME/.config/ 

sudo cp -f AwesomeDots/config.ini /etc/ly/ #login manager

git clone https://github.com/streetturtle/awesome-wm-widgets.git $HOME/.config/awesome/awesome-wm-widgets #window_manager widgets

cp -f AwesomeDots/xinitrc $HOME/.xinitrc #startup 

mv AwesomeDots/scripts $HOME/
chmod +x scripts/*
cp AwesomeDots/alacrittypywal.sh $HOME/ #color alacritty with pywal
sudo cp $HOME/scripts/dexplore /usr/bin/ #search web indexes
sudo cp $HOME/scripts/newq /usr/bin/ #pywal wrapper/wallpaper selector
sudo cp $HOME/scripts/ocean /usr/bin/ #newsboat open links
sudo cp $HOME/scripts/shredder /usr/bin/ #fzf shred script
sudo cp $HOME/scripts/dnetd-cli /usr/bin/ #play Darknet-Diaries from the terminal.
#sudo cp $HOME/scripts/fixmon /usr/bin/ #multimonitor setup

read -p "Get wallpapers? (y/n): " walp
if [[ $walp = [y,Y] ]] ; then
	if [[ $(curl -s "https://sudormrf.tech/wallpapers/") = "error code: 1033" ]] ; then  
		echo "Not Found!" 1>&2; 
		exit 1 
	fi
	wget -q --show-progress -r -nH --cut-dirs=2 --no-parent --reject='index.html*' "https://sudormrf.tech/wallpapers/"
	echo "Wallpapers Acquired!"
fi

echo -e "COMPLETE \n on fresh install run 'startx' to start Xorg."
