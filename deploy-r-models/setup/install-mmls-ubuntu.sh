#!/bin/bash
declare password=""

# Initialize parameters specified from command line
while getopts ":p:" arg; do
	case "${arg}" in
		p)
			password=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

if [[ -z "$password" ]]; then
	while : ; do
		echo -n "Enter a password for the Machine Learning Server admin:"
		read -s password
		echo
		echo -n "Please repeat the password for the Machine Learning Server admin:"
		read -s password_confirm
		echo
		if [[ "$password" == "$password_confirm" ]]; then
			break
		else
			echo "The passwords do not match. Please retry."
		fi
	done
fi

# Optionally, if your system does not have the https apt transport option
apt-get install apt-transport-https

# Add the **azure-cli** repo to your apt sources list
AZ_REPO=$(lsb_release -cs)

echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | sudo tee /etc/apt/sources.list.d/azure-cli.list

# Set the location of the package repo the "prod" directory containing the distribution.
# This example specifies 16.04. Replace with 14.04 if you want that version
wget https://packages.microsoft.com/config/ubuntu/16.04/packages-microsoft-prod.deb

# Register the repo
dpkg -i packages-microsoft-prod.deb

# Remove deb file
rm -rf packages-microsoft-prod.deb

# Add the Microsoft public signing key for Secure APT
apt-key adv --keyserver packages.microsoft.com --recv-keys 52E16F86FEE04B979B07E28DB02C46DF417A0893

# Update packages on your system
apt-get update

# Install the server
apt-get install -y microsoft-mlserver-all-9.4.7

# Activate the server
/opt/microsoft/mlserver/9.4.7/bin/R/activate.sh -a -l

# Set up both o16n nodes on one machine
az mlserver admin node setup --onebox --admin-password $password --confirm-password $password
