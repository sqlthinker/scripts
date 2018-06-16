#Requires -Version 5
##################################################################################################################
#.SYNOPSIS
# Move Azure VM from one subscription to another
#
#.DESCRIPTION
# Move Azure VM from one subscription to another
# It will also create a new Resource Group, Virtual Network, Security in the target subscription
#
#.NOTES
# AUTHOR: Anibal Santiago - @SQLThinker
#
# Some useful commands to get information needed by this script
#   Login-AzureRMAccount
#   Get-AzureRmSubscription | FT SubscriptionId, Name
#   Get-AzureRmResourceGroup
#   Get-AzureRmVM
#   Get-AzureRmDisk -ResourceGroupName "wordpress"
#
# -- Links where this script is based from
# https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-copy-managed-disks-to-same-or-different-subscription
# https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-create-vm-from-managed-os-disks
##################################################################################################################


##################################################################
## Provide a value for the variables in this section
##################################################################
## Subscription Id of the subscription where managed disk exists
$sourceSubscriptionId = '12345678-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

## Name of your resource group where managed disk exists
$sourceResourceGroupName = 'MySourceResourceGroup'

## Name of the managed OS disk used by the source VM
$sourceManagedDiskName = 'MySourceManageDisk'

## Subscription Id of the subscription where managed disk will be copied to
$targetSubscriptionId = '12345678-yyyy-yyyy-yyyy-yyyyyyyyyyyy'

## Target prefix to add too all objects created in target subscription
$targetPrefix = "TargetPrefixToNameAllObjects"

## Name of the managed disk on the targe subscription (in case you want to use a different name)
$targetManagedDiskName = "$($targetPrefix)_OsDisk"

# Name of the resource group where snapshot will be copied to
$targetResourceGroupName ="$($targetPrefix)_RG"

# Location of the new VM
$targetLocation = "EastUS"

# Virtual network and subnet where virtual machine will be created
$targetVNetName      = "$($targetPrefix)_VNet"
$targetSubnet1       = "$($targetPrefix)_subnet1"
$targetVNetAddress   = "10.0.0.0/16"
$targetSubnetAddress = "10.0.0.0/24"

# Size of the virtual machine. Get all the vm sizes in a region: Get-AzureRmVMSize -Location EastUS
$targetVMSize = "Standard_B2s"  # Standard_B1s

# Name of the virtual machine
$targetVMName = "$($targetPrefix)_VM"

# Name of the Network Security Group
$targetNetworkSecurityGroup = "$($targetPrefix)_NSG"


##################################################################
## This section will do the VM migration
##################################################################
## Set the context to the source subscription
Select-AzureRmSubscription -SubscriptionId $sourceSubscriptionId

## Get the source managed disk
$managedDisk = Get-AzureRMDisk `
  -ResourceGroupName $sourceResourceGroupName `
  -DiskName $sourceManagedDiskName


## Change the context to the target subscription
Select-AzureRmSubscription -SubscriptionId $targetSubscriptionId

## Create the Resource Group in the target subscription
Set-AzureRmContext -SubscriptionId $targetSubscriptionId
New-AzureRmResourceGroup -Name $targetResourceGroupName -Location $targetLocation


# Create a new managed disk in the target subscription and resource group
$diskConfig = New-AzureRmDiskConfig `
  -SourceResourceId $managedDisk.Id `
  -Location $managedDisk.Location `
  -CreateOption Copy

$disk = New-AzureRmDisk `
  -Disk $diskConfig `
  -DiskName $targetManagedDiskName `
  -ResourceGroupName $targetResourceGroupName


## Create a memory representation of the new Virtual Network
$virtualNetwork = New-AzureRmVirtualNetwork `
  -ResourceGroupName $targetResourceGroupName `
  -Location $targetLocation `
  -Name $targetVNetName `
  -AddressPrefix $targetVNetAddress

## Create a subnet configuration to add to the Virtual Network
$subnetConfig = Add-AzureRmVirtualNetworkSubnetConfig `
  -Name $targetSubnet1 `
  -AddressPrefix $targetSubnetAddress `
  -VirtualNetwork $virtualNetwork


## Create firewall rules
# Allow http traffic
$httprule = New-AzureRmNetworkSecurityRuleConfig `
  -Name "HTTP" `
  -Description "Allow HTTP" `
  -Access "Allow" `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority "100" `
  -SourceAddressPrefix "Internet" `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 80

# Allow https traffic
$httpsrule = New-AzureRmNetworkSecurityRuleConfig `
  -Name "HTTPS" `
  -Description "Allow HTTPS" `
  -Access "Allow" `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority "101" `
  -SourceAddressPrefix "Internet" `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 443

# Allow https traffic
$httpsrule = New-AzureRmNetworkSecurityRuleConfig `
  -Name "HTTPS" `
  -Description "Allow HTTPS" `
  -Access "Allow" `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority "101" `
  -SourceAddressPrefix "Internet" `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 443

# Allow SSH
$sshrule = New-AzureRmNetworkSecurityRuleConfig `
  -Name "SSH" `
  -Description "Allow SSH" `
  -Access "Allow" `
  -Protocol "Tcp" `
  -Direction "Inbound" `
  -Priority "102" `
  -SourceAddressPrefix "Internet" `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 22

## Create a Network Security Group
$nsg = New-AzureRmNetworkSecurityGroup `
  -ResourceGroupName $targetResourceGroupName `
  -Location $disk.Location `
  -Name $targetNetworkSecurityGroup `
  -SecurityRules $httprule,$httpsrule,$sshrule

## Link the NSG with the subnet config created earlier
Set-AzureRmVirtualNetworkSubnetConfig `
  -VirtualNetwork $virtualNetwork `
  -Name $subnetConfig.Subnets.Name `
  -AddressPrefix $subnetConfig.Subnets.AddressPrefix `
  -NetworkSecurityGroup $nsg

## Create the Virtual Network
Set-AzureRmVirtualNetwork -VirtualNetwork $virtualNetwork


## Initialize virtual machine configuration
$VirtualMachine = New-AzureRmVMConfig `
  -VMName $targetVMName `
  -VMSize $targetVMSize

## Use the Managed Disk Resource Id to attach it to the virtual machine
$VirtualMachine = Set-AzureRmVMOSDisk `
  -VM $VirtualMachine `
  -ManagedDiskId $disk.Id `
  -CreateOption Attach -Linux

## Create a public IP for the VM
$publicIp = New-AzureRmPublicIpAddress `
  -Name ($targetVMName + '_IP') `
  -ResourceGroupName $targetResourceGroupName `
  -Location $disk.Location `
  -AllocationMethod Dynamic

## Get the virtual network where virtual machine will be hosted
 $vnet = Get-AzureRmVirtualNetwork `
   -Name $targetVNetName `
   -ResourceGroupName $targetResourceGroupName

## Create NIC in the first subnet of the virtual network
$nic = New-AzureRmNetworkInterface `
  -Name ($targetVMName + '_NIC') `
  -ResourceGroupName $targetResourceGroupName `
  -Location $disk.Location `
  -SubnetId $vnet.Subnets[0].Id `
  -PublicIpAddressId $publicIp.Id

$VirtualMachine = Add-AzureRmVMNetworkInterface `
  -VM $VirtualMachine `
  -Id $nic.Id

## Create the virtual machine with Managed Disk
New-AzureRmVM -VM $VirtualMachine `
  -ResourceGroupName $targetResourceGroupName `
  -Location $disk.Location

## Run this command to get the information about the new VM
#Get-AzureRmVM -Name $targetVMName -ResourceGroupName $targetResourceGroupName


## Display the Public IP of the new VM
$publicIp = Get-AzureRmPublicIpAddress `
  -Name ($targetVMName.ToLower()+'_ip') `
  -ResourceGroupName $targetResourceGroupName
Write-Host "Public IP Addres: $($publicIp.IpAddress)"


## Cleanup - Run only if undoing the creation of the new Resource Group
# Remove-AzureRmResourceGroup -Name $targetResourceGroupName
