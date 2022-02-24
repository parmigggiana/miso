#!/bin/bash
# WEEEDebian creation script - a-porsia et al
# export PATH="$PATH:/usr/sbin:/usr/bin:/sbin:/bin"

echo "Martello is starting!"

echo "[SeatDefaults]" >> /usr/share/lightdm/lightdm.conf.d/01_debian.conf
echo "autologin-user=<nome user>" >> /usr/share/lightdm/lightdm.conf.d/01_debian.conf
echo "autologin-user-timeout=0"  >> /usr/share/lightdm/lightdm.conf.d/01_debian.conf

echo "=== Software installation ==="
# Remove useless packages, courtesy of "wajig large". Cool command.
# Do not remove mousepad, it removes xfce-goodies too
#/bin/bash -c 'DEBIAN_FRONTEND=noninteractive apt-getpurge --auto-remove -y libreoffice libreoffice-core libreoffice-common ispell* gimp gimp-* aspell* hunspell* mythes* *sunpinyin* wpolish wnorwegian tegaki* task-thai task-thai-desktop xfonts-thai xiterm* task-khmer task-khmer-desktop fonts-khmeros khmerconverter'
# Upgrade and install useful packages
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
# libxkbcommon-x11-0 may be not needed (see Add library to installation if needed #28)
apt-get install -y\
    apt-transport-https \
    ca-certificates \
    cifs-utils \
    curl \
    curl \
    dmidecode \
    firefox-esr \
    geany \
    git \
    gparted \
    gsmartcontrol \
    gvfs-backends \
    i2c-tools \
    iputils-tracepath \
    libglu1-mesa-dev \
    libx11-xcb-dev \
    '^libxcb.*-dev' \
    libxi-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-0 \
    libxkbcommon-x11-dev \
    libxrender-dev \
    lightdm \
    lshw \
    mesa-utils \
    nano \
    net-tools \
    network-manager \
    openssh-client \
    openssh-server \
    openssl \
    pciutils \
    rsync \
    smartmontools \
    sudo \
    sudo \
    traceroute \
    wget \
    wireless-tools \
    wpagui \
    xfce4 \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    xinit \
    xorg \
    xserver-xorg \
    xserver-xorg-core \
    zsh
update-ca-certificates

echo "=== User configuration ==="
# openssl has been installed, so this can be done now
MISO_ROOTPASSWD=$(openssl passwd -6 "$MISO_ROOTPASSWD")
MISO_USERPASSWD=$(openssl passwd -6 "$MISO_USERPASSWD")
if [[ -z `grep weee /etc/passwd` ]]; then
    useradd -m -G sudo -s /bin/zsh weee
fi
# The -p parameter is silently ignored for some reason:
# -p "$6$cFAyjyCf$HiQKwzGvDioyYINpJ0kKmHEy6kXUlBJViMkd1ceizIpBFOftLVnjCuT6wvfLVhG7qnCo10q3vGzsaeyFIYHMO."
# This ALSO does not work:
#echo "weee:asd" | chpasswd
# So...
sed -i "s#root:.*#root:$ROOTPASSWD:18214:0:99999:7:::#" /etc/shadow
sed -i "s#$MISO_USERNAME:.*#$MISO_USERNAME:$MISO_USERPASSWD:18214:0:99999:7:::#" /etc/shadow
chsh -s /bin/zsh root
# chsh -s /bin/zsh weee
runuser -l $MISO_USERNAME -c "curl -L -o /home/$MISO_USERNAME/.zshrc https://git.grml.org/f/grml-etc-core/etc/zsh/zshrc"
cp /home/$MISO_USERNAME/.zshrc /root/.zshrc
runuser -l $MISO_USERNAME -c "rm /home/$MISO_USERNAME/.bash_history  >/dev/null 2>/dev/null"
rm /root/.bash_history >/dev/null 2>/dev/null

echo "=== Keymap configuration ==="
echo "KEYMAP=it" > /etc/vconsole.conf
# Probably not needed:
# echo "LANG=it_IT.UTF-8" > /etc/locale.conf
# 00-keyboard.conf can be managed by localectl. In fact, this is one of such files produced by localectl.
mkdir -p /etc/X11/xorg.conf.d
cp ./00-keyboard.conf /etc/X11/xorg.conf.d/00-keyboard.conf

echo "=== Locale configuration ==="
cp ./locale.gen /etc/locale.gen
cp ./locale.conf /etc/locale.conf
locale-gen
. /etc/locale.conf
locale

echo "=== SSH daemon configuration ==="
cp ./sshd_config /etc/ssh/sshd_config

echo "=== Modules configuration ==="
if [[ ! -f "/etc/modules-load.d/eeprom.conf" ]]; then
  touch /etc/modules-load.d/eeprom.conf
fi
if [[ -z `grep eeprom /etc/modules-load.d/eeprom.conf` ]]; then
    printf "eeprom\n" > /etc/modules-load.d/eeprom.conf
fi
if [[ -z `grep at24 /etc/modules-load.d/eeprom.conf` ]]; then
    printf "at24\n" > /etc/modules-load.d/eeprom.conf
fi

echo "=== Sudo configuration ==="
cp ./weee /etc/sudoers.d/weee

echo "=== DNS configuration ==="
cp ./resolv.conf /etc/resolv.conf
cp ./resolved.conf /etc/systemd/resolved.conf
rm -f /var/run/NetworkManager/* 2>/dev/null

echo "=== NTP configuration ==="
systemctl enable systemd-timesyncd
rm -f /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Rome /etc/localtime

echo "=== Top configuration ==="
cp ./toprc /root/.toprc
runuser -l $MISO_USERNAME -c "cp ./toprc /home/$MISO_USERNAME/.toprc"

echo "=== Prepare peracotta ==="
/bin/bash -c 'apt-get install -y python3-pip'
# PyQt > 5.14.0 requires an EXTREMELY RECENT version of pip,
# on the most bleeding of all bleeding edges
python3 -m pip install --quiet --upgrade pip

cp ./peracotta_update /etc/cron.d/peracotta_update

if [[ -d "/home/$MISO_USERNAME/peracotta" ]]; then
  rm -rf "/home/$MISO_USERNAME/peracotta"
  #runuser -l $MISO_USERNAME -c "git -C /home/$MISO_USERNAME/peracotta pull"
fi
#else
runuser -l $MISO_USERNAME -c "mkdir -p /home/$MISO_USERNAME/peracotta"
runuser -l $MISO_USERNAME -c "git clone https://github.com/WEEE-Open/peracotta.git /home/$MISO_USERNAME/peracotta"
#fi

#runuser -l $MISO_USERNAME -c "sh -c 'cd /home/$MISO_USERNAME/peracotta && python3 polkit.py'"
runuser -l $MISO_USERNAME -c "cp ./features.json /home/$MISO_USERNAME/peracotta/features.json"

if [[ "x$(dpkg --print-architecture)" == "xi386" ]]; then
  echo ""===== Begin incredible workaround for PyQt on 32 bit =====""
  /bin/bash -c 'apt-get install -y python3-pyqt5'
  runuser -l $MISO_USERNAME -c "/bin/bash -c \"grep -vi "pyqt" /home/$MISO_USERNAME/peracotta/requirements.txt > /home/$MISO_USERNAME/peracotta/requirements32.txt\""
  pip3 --quiet install -r /home/$MISO_USERNAME/peracotta/requirements32.txt
  rm -f /home/$MISO_USERNAME/peracotta/requirements32.txt
  echo ""===== End incredible workaround for PyQt on 32 bit =====""
else
  /bin/bash -c 'apt-get autoremove -y python3-pyqt5'
  pip3 --quiet install -r /home/$MISO_USERNAME/peracotta/requirements.txt
fi

PERACOTTA_GENERATE_FILES=$(runuser -l $MISO_USERNAME -c "find /home/$MISO_USERNAME/peracotta -name generate_files* -print -quit")
PERACOTTA_MAIN=$(runuser -l $MISO_USERNAME -c "find /home/$MISO_USERNAME/peracotta -name peracruda -print -quit")
PERACOTTA_MAIN_WITH_GUI=$(runuser -l $MISO_USERNAME -c "find /home/$MISO_USERNAME/peracotta -name peracotta -print -quit")

if [[ -f "$PERACOTTA_GENERATE_FILES" ]]; then
  runuser -l $MISO_USERNAME -c 'chmod +x "$PERACOTTA_GENERATE_FILES"'
  ln -s "$PERACOTTA_GENERATE_FILES" /usr/bin/generate_files
fi
if [[ -f "$PERACOTTA_MAIN" ]]; then
  runuser -l $MISO_USERNAME -c 'chmod +x "$PERACOTTA_MAIN"'
fi
if [[ -f "$PERACOTTA_MAIN_WITH_GUI" ]]; then
  runuser -l $MISO_USERNAME -c 'chmod +x "$PERACOTTA_MAIN_WITH_GUI"'
fi

echo "=== Add env to peracotta ==="
if [[ -f "./env.txt" ]]; then
  runuser -l $MISO_USERNAME -c "cp ./env.txt /home/$MISO_USERNAME/peracotta/.env"
else
  echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  echo "@                                                          @"
  echo "@                         WARNING                          @"
  echo "@                                                          @"
  echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
  echo "@                                                          @"
  echo "@   env.txt not found in weeedebian_files.                 @"
  echo "@   You're missing out many great peracotta features!      @"
  echo "@   Check README for more info if you want to create the   @"
  echo "@   file and automate your life!                           @"
  echo "@                                                          @"
  echo "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
fi

echo "=== s.sh ==="
cp ./s.sh /usr/sbin/s.sh
chmod +x /usr/sbin/s.sh
runuser -l $MISO_USERNAME -c "cp ./ssh.desktop /home/$MISO_USERNAME/Desktop"
runuser -l $MISO_USERNAME -c "chmod +x /home/$MISO_USERNAME/Desktop/ssh.desktop"

echo "=== XFCE configuration ==="
runuser -l $MISO_USERNAME -c "mkdir -p /home/$MISO_USERNAME/.config/xfce4"
rsync -a --force ./xfce4 /home/$MISO_USERNAME/.config
chown weee: -R /home/$MISO_USERNAME/.config
runuser -l $MISO_USERNAME -c "mkdir /home/$MISO_USERNAME/.config/xfce4/desktop /home/$MISO_USERNAME/.config/xfce4/terminal"

echo "=== Desktop shortcuts ==="
if [[ -d "/home/$MISO_USERNAME/limone" ]]; then
  runuser -l $MISO_USERNAME -c "git -C /home/$MISO_USERNAME/limone pull"
else
  runuser -l $MISO_USERNAME -c "mkdir -p /home/$MISO_USERNAME/limone"
  runuser -l $MISO_USERNAME -c "git clone https://github.com/WEEE-Open/limone.git /home/$MISO_USERNAME/limone"
fi

runuser -l $MISO_USERNAME -c "mkdir -p /home/$MISO_USERNAME/Desktop"

for desktop_file in $(runuser -l $MISO_USERNAME -c "find /home/$MISO_USERNAME/limone -name \"*.desktop\" -type f -printf \"%f \""); do
  runuser -l $MISO_USERNAME -c "cp \"/home/$MISO_USERNAME/limone/\$desktop_file\" \"/home/$MISO_USERNAME/Desktop/\$desktop_file\""
  runuser -l $MISO_USERNAME -c "chmod +x \"/home/$MISO_USERNAME/Desktop/$desktop_file\""
  sed -ri -e "s#Icon=(.*/)*([a-zA-Z0-9\-\.]+)#Icon=/home/$MISO_USERNAME/limone/\2#" "/home/$MISO_USERNAME/Desktop/$desktop_file"
done

runuser -l $MISO_USERNAME -c "cp ./Peracotta.desktop /home/$MISO_USERNAME/Desktop"
runuser -l $MISO_USERNAME -c "cp ./peracotta.png /home/$MISO_USERNAME/.config/peracotta.png"
runuser -l $MISO_USERNAME -c "chmod +x /home/$MISO_USERNAME/Desktop/Peracotta.desktop"

runuser -l $MISO_USERNAME -c "cp ./PeracottaGUI.desktop /home/$MISO_USERNAME/Desktop"
runuser -l $MISO_USERNAME -c "cp ./peracotta_gui.png /home/$MISO_USERNAME/.config/peracotta_gui.png"
runuser -l $MISO_USERNAME -c "chmod +x /home/$MISO_USERNAME/Desktop/PeracottaGUI.desktop"

echo "=== Pointerkeys thing ==="
runuser -l $MISO_USERNAME -c "mkdir -p /home/$MISO_USERNAME/.config/autostart"
runuser -l $MISO_USERNAME -c "cp ./Pointerkeys.desktop /home/$MISO_USERNAME/.config/autostart/Pointerkeys.desktop"
runuser -l $MISO_USERNAME -c "cp ./pointerkeys.txt /home/$MISO_USERNAME/Desktop"

echo "=== Autologin stuff ==="
cat << EOF > /etc/lightdm/lightdm.conf
[LightDM]

[Seat:*]
autologin-user=$MISO_USERNAME
autologin-user-timeout=0
EOF
mkdir -p /etc/systemd/system/getty@.service.d
touch /etc/systemd/system/getty@.service.d/override.conf
printf "[Service]\n" > /etc/systemd/system/getty@.service.d/override.conf
printf "ExecStart=\n" >> /etc/systemd/system/getty@.service.d/override.conf
printf "ExecStart=-/sbin/agetty --noissue --autologin weee %%I $TERM" >> /etc/systemd/system/getty@.service.d/override.conf

echo "=== Set hostname ==="
echo "$MISO_HOSTNAME" > /etc/hostname

echo "=== Final cleanup ==="
# Remove unused packages
/bin/bash -c 'apt-get autoremove -y'
# Clean the cache
/bin/bash -c 'apt-get clean -y'

  echo "=== Automatic configuration done ==="
  read -p 'Open a shell in the chroot environment? [y/n] ' ans
      if [[ $ans == "y" ]]; then
          runuser -l $MISO_USERNAME -c '/bin/bash'
      fi
