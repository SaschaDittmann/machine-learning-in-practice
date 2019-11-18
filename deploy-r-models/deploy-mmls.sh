#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -v <vm-name> -u <admin-username> -p <admin-password>" 1>&2; exit 1; }

declare subscriptionId=""
declare resourceGroupName=""
declare deploymentName="msftmlsvr-`date '+%Y-%m-%d-%H-%M-%S'`"
declare resourceGroupLocation=""
declare vmPrefix=""
declare username="" 
declare password=""

# Initialize parameters specified from command line
while getopts ":i:g:n:l:v:u:p:" arg; do
	case "${arg}" in
		i)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		n)
			deploymentName=${OPTARG}
			;;
		l)
			resourceGroupLocation=${OPTARG}
			;;
		v)
			vmPrefix=${OPTARG}
			;;
		u)
			username=${OPTARG}
			;;
		p)
			password=${OPTARG}
			;;
		esac
done
shift $((OPTIND-1))

# Requirements check: jq
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required by this script but it's not installed. Please check https://stedolan.github.io/jq/download/ for details how to install jq."; exit 1; }

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
	echo "Your subscription ID can be looked up with the CLI using: az account show --out json "
	echo "Enter your subscription ID:"
	read subscriptionId
	[[ "${subscriptionId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name: "
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$deploymentName" ]]; then
	echo "Enter a name for this deployment:"
	read deploymentName
fi

if [[ -z "$resourceGroupLocation" ]]; then
	echo "If creating a *new* resource group, you need to set a location "
	echo "You can lookup locations with the CLI using: az account list-locations "
	
	echo "Enter resource group location:"
	read resourceGroupLocation
fi

if [[ -z "$vmPrefix" ]]; then
	echo "Enter a name for the virtual machine:"
	read vmPrefix
fi

if [[ -z "$username" ]]; then
	echo "Enter a username for the vm admin:"
	read username
fi

if [[ -z "$password" ]]; then
	while : ; do
		echo -n "Enter a password for the vm admin:"
		read -s password
		echo
		echo -n "Please repeat the password for the vm admin:"
		read -s password_confirm
		echo
		if [[ "$password" == "$password_confirm" ]]; then
			break
		else
			echo "The passwords do not match. Please retry."
		fi
	done
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$deploymentName" ]; then
	echo "Either one of subscriptionId, resourceGroupName, deploymentName is empty"
	usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

set +e

#Check for existing RG
az group show --name $resourceGroupName 1> /dev/null

if [ $? != 0 ]; then
	echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
	set -e
	(
		set -x
		az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
	)
	else
	echo "Using existing resource group..."
fi

echo "Starting deployment..."

#Start deployment
echo "Virtual Network..."
(
	set -x
	az network vnet create -g "$resourceGroupName" -n "$vmPrefix-vnet" --address-prefix 10.0.0.0/16 \
        --subnet-name default --subnet-prefix 10.0.0.0/24 \
		| jq -r .newVNet.provisioningState
)

echo "Network Security Group with 3 Rules..."
(
	set -x
	az network nsg create -g "$resourceGroupName" -n "$vmPrefix-nsg" | jq -r .NewNSG.provisioningState

	az network nsg rule create -g "$resourceGroupName" --nsg-name "$vmPrefix-nsg" -n "MLSvr_WebNode" \
		--priority 1000 --access Allow --protocol Tcp --direction Inbound \
		--destination-address-prefixes '*' --destination-port-ranges 12800 \
		| jq -r .provisioningState

	az network nsg rule create -g "$resourceGroupName" --nsg-name "$vmPrefix-nsg" -n "MLSvr_ComputeNode" \
		--priority 1100 --access Allow --protocol Tcp --direction Inbound \
		--destination-address-prefixes '*' --destination-port-ranges 12805 \
		| jq -r .provisioningState

	az network nsg rule create -g "$resourceGroupName" --nsg-name "$vmPrefix-nsg" -n "MLSvr_RServe" \
		--priority 1200 --access Allow --protocol Tcp --direction Inbound \
		--destination-address-prefixes '*' --destination-port-ranges 9054 \
		| jq -r .provisioningState
)

echo "Public IP & NIC..."
(
	set -x
	az network public-ip create -g "$resourceGroupName" -n "$vmPrefix-ip" --sku Basic \
		| jq -r .publicIp.provisioningState
	az network nic create -g "$resourceGroupName" -n "$vmPrefix-nic" --vnet-name "$vmPrefix-vnet" \
		--subnet default --network-security-group "$vmPrefix-nsg" --public-ip-address "$vmPrefix-ip" \
		| jq -r .NewNIC.provisioningState
)

echo "Virtual Machine..."
(
	az vm create -g "$resourceGroupName" -n "$vmPrefix" \
		--image Canonical:UbuntuServer:16.04-LTS:latest --size Standard_D2s_v3 \
        --authentication-type password --admin-username "$username" --admin-password $password \
        --nics "$vmPrefix-nic" --os-disk-name "$vmPrefix-osdisk" --enable-agent "true"
)

echo "Microsoft Machine Learning Server..."
(
	az vm extension set -g "$resourceGroupName" -n "customScript" \
		--vm-name "$vmPrefix" --publisher Microsoft.Azure.Extensions \
		--protected-settings "{\"fileUris\": [\"https://raw.githubusercontent.com/SaschaDittmann/machine-learning-in-practice/master/deploy-r-models/setup/install-mmls-ubuntu.sh\"],\"commandToExecute\": \"./install-mmls-ubuntu.sh -p '$password'\"}" \
		| jq -r .provisioningState
)

if [ $?  == 0 ];
 then
	echo "Microsoft Machine Learning Server has been successfully deployed"
fi
