#!/bin/bash

#<UDF name="ssuser" Label="Sudo user username?" example="username" />
#<UDF name="sspassword" Label="Sudo user password?" example="strongPassword" />
#<UDF name="pubkey" Label="SSH pubkey (installed for root and sudo user)?" example="ssh-rsa ..." />

if [[ ! $SSUSER ]]; then read -p "Sudo user username?" SSUSER; fi
if [[ ! $SSPASSWORD ]]; then read -p "Sudo user password?" SSPASSWORD; fi
if [[ ! $SSPUBKEY ]]; then read -p "SSH pubkey (installed for root and sudo user)?" SSPUBKEY; fi

# set up sudo user
echo Setting sudo user: $SSUSER...
useradd $SSUSER && echo $SSPASSWORD | passwd $SSUSER --stdin
usermod -aG wheel $SSUSER
echo ...done

# set up ssh pubkey
echo Setting up ssh pubkeys...
mkdir -p /root/.ssh
mkdir -p /home/$SSUSER/.ssh
echo "$SSPUBKEY" >> /root/.ssh/authorized_keys
echo "$SSPUBKEY" >> /home/$SSUSER/.ssh/authorized_keys
chmod -R 700 /root/.ssh
chmod -R 700 /home/${SSUSER}/.ssh
chown -R ${SSUSER}:${SSUSER} /home/${SSUSER}/.ssh
echo ...done

# disable password over ssh
echo Disabling passwords and root login over ssh...
sed -i -e "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "s/#PermitRootLogin no/PermitRootLogin no/" /etc/ssh/sshd_config
sed -i -e "s/PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sed -i -e "s/#PasswordAuthentication no/PasswordAuthentication no/" /etc/ssh/sshd_config
echo Restarting sshd...
systemctl restart sshd
echo ...done

# Initial needfuls
yum update -y
yum install -y epel-release
yum update -y

#remove unneeded services
echo Removing unneeded services...
yum remove -y avahi chrony
echo ...done

# Set up automatic  updates
echo Setting up automatic updates...
yum install -y yum-cron
sed -i -e "s/apply_updates = no/apply_updates = yes/" /etc/yum/yum-cron.conf
echo ...done
# auto-updates complete

#set up fail2ban
echo Setting up fail2ban...
yum install -y fail2ban
cd /etc/fail2ban
cp fail2ban.conf fail2ban.local
cp jail.conf jail.local
sed -i -e "s/backend = auto/backend = systemd/" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl start fail2ban
echo ...done

# ensure ntp is installed and running
yum install -y ntp
systemctl enable ntpd
systemctl start ntpd

# set up firewalld
echo Setting up firewalld...
systemctl start firewalld
systemctl enable firewalld

# Use public zone
firewall-cmd --set-default-zone=public
firewall-cmd --zone=public --add-interface=eth0
firewall-cmd --reload
echo ...done


#
# Set up distro kernel and grub
echo "Setting up distro kernel and grub"
yum install -y kernel grub2
sed -i -e "s/GRUB_TIMEOUT=5/GRUB_TIMEOUT=10/" /etc/default/grub
sed -i -e "s/crashkernel=auto rhgb console=ttyS0,19200n8/console=ttyS0,19200n8/" /etc/default/grub
mkdir /boot/grub
grub2-mkconfig -o /boot/grub/grub.cfg
echo "...done"
sleep 1

# Install Docker
echo "installing docker..."

# Remove unneeded docker packages
yum remove -y docker docker-client docker-client-latest docker-common docker-latest \
              docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux \
              docker-engine
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce
systemctl enable docker
systemctl start docker
echo "...done"
sleep 1
#

echo "installing docker-compose..."
curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "configuring docker user"
usermod -aG docker $SSUSER

echo "installing git..."
yum install -y git

echo "cloning geo-docker library and starting geomesa..."
su $SSUSER -c 'cd ~ && git clone https://github.com/geodocker/geodocker-geomesa.git && cd ~/geodocker-geomesa/geodocker-accumulo-geomesa && docker-compose pull;'
echo "getting opensky data from Aug 18"
curl -o upgrade_python.sh -L https://raw.githubusercontent.com/brownnrl/linux-deployment-scripts/master/GeoDocker/upgrade_python.sh && chmod +x upgrade_python.sh && ./upgrade_python.sh
su $SSUSER -c 'cd ~ && curl -o googledoc.py -L https://raw.githubusercontent.com/brownnrl/linux-deployment-scripts/master/GeoDocker/googledoc.py && chmod +x googledoc.py && ./googledoc.py 19GHBWBresVR6ZTfgRBQNzR_iIW-vXU3e opensky.csv.id'


#
echo All finished!