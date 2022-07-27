#!/bin/bash -uxe
# A bash script that prepares the OS
# before running the Ansible playbook

# Discard stdin. Needed when running from an one-liner which includes a newline
read -N 999999 -t 0.001

# Quit on error
set -e

# Detect OS
if grep -qs "ubuntu" /etc/os-release; then
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
else
	echo "This installer seems to be running on an unsupported distribution.
Supported distros are Ubuntu 20.04 and 22.04"
	exit
fi

# Check if the Ubuntu version is too old
if [[ "$os" == "ubuntu" && "$os_version" -lt 2004 ]]; then
	echo "Ubuntu 20.04 or higher is required to use this installer.
This version of Ubuntu is too old and unsupported."
	exit
fi


check_root() {
# Check if the user is root or not
if [[ $EUID -ne 0 ]]; then
  if [[ ! -z "$1" ]]; then
    SUDO='sudo -E -H'
  else
    SUDO='sudo -E'
  fi
else
  SUDO=''
fi
}

check_root
# Disable interactive functionality
export DEBIAN_FRONTEND=noninteractive

# Update apt database, update all packages and install Ansible + dependencies
$SUDO apt update -y;
yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy dist-upgrade;
yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy install software-properties-common certbot dnsutils curl git python3 python3-setuptools python3-apt python3-pip python3-passlib python3-wheel python3-bcrypt aptitude -y;
yes | $SUDO apt-get -o Dpkg::Options::="--force-confold" -fuy autoremove;
[ $(uname -m) == "aarch64" ] && $SUDO yes | apt install gcc dnsutils python3-dev libffi-dev libssl-dev make -y;

check_root "-H"

$SUDO pip3 install ansible &&
export DEBIAN_FRONTEND=

check_root
# Clone the Ansible playbook
[ -d "$HOME/luma-ansible" ] || git clone https://github.com/matfire/luma-ansible.git $HOME/luma-ansible

cd $HOME/luma-ansible && ansible-galaxy install -r requirements.yml

clear
echo "Welcome to luma!"
echo
echo "This script is interactive"
echo "If you prefer to fill in the inventory.yml file manually,"
echo "press [Ctrl+C] to quit this script"
echo

echo
echo "Enter your luma user password"
echo "This password will be used to access the luma user"
read -s -p "Password: " user_password
until [[ "${#user_password}" -lt 60 ]]; do
  echo
  echo "The password is too long"
  echo "OpenSSH does not support passwords longer than 72 characters"
  read -s -p "Password: " user_password
done
echo
read -s -p "Repeat password: " user_password2
echo
until [[ "$user_password" == "$user_password2" ]]; do
  echo
  echo "The passwords don't match"
  read -s -p "Password: " user_password
  echo
  read -s -p "Repeat password: " user_password2
done

echo
echo "Enter the GIT URL you wish to clone"
read -p "Git URL: " luma_url

echo -e "    luma_git: ${luma_url}" >> $HOME/luma-ansible/inventory.yml

echo
echo "Enter the name of the project"
read -p "Project Name: " luma_project

echo -e "    luma_project: ${luma_project}" >> $HOME/luma-ansible/inventory.yml



echo
echo
echo "Enter your domain name"
echo
read -p "Domain name: " root_host
until [[ "$root_host" =~ ^[a-z0-9\.\-]*$ ]]; do
  echo "Invalid domain name"
  read -p "Domain name: " root_host
done

echo -e "    root_host: ${root_host}" >> $HOME/luma-ansible/inventory.yml


touch $HOME/luma-ansible/secret.yml
chmod 600 $HOME/luma-ansible/secret.yml


echo "user_password: ${user_password}" >> $HOME/luma-ansible/secret.yml
echo
echo "Encrypting the variables"
ansible-vault encrypt $HOME/luma-ansible/secret.yml



echo
echo "Success!"
read -p "Would you like to run the playbook now? [y/N]: " launch_playbook
until [[ "$launch_playbook" =~ ^[yYnN]*$ ]]; do
				echo "$launch_playbook: invalid selection."
				read -p "[y/N]: " launch_playbook
done

if [[ "$launch_playbook" =~ ^[yY]$ ]]; then
  if [[ $EUID -ne 0 ]]; then
    echo
    echo "Please enter your current sudo password now"
    cd $HOME/luma-ansible && ansible-playbook -K run.yml
  else
    cd $HOME/luma-ansible && ansible-playbook run.yml
  fi
else
  echo "You can run the playbook by executing the following command"
  echo "cd ${HOME}/luma-ansible && ansible-playbook run.yml"
  exit
fi