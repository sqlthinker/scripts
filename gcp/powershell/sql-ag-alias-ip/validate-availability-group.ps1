#Requires -Version 5
# Copyright(c) 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

###############################################################################
#.SYNOPSIS
# Validate that the Availability Group is working
#
#.DESCRIPTION
# This script can be used to check that the Availability group is working as 
# expected. It can check that the nodes are synchronized and that failover
# is working. 


Set-Location $PSScriptRoot

################################################################################
# Read the parameters for this script. They are found in the file 
# parameters-config.ps1. We assume it is in the same folder as this script
################################################################################
. ".\parameters-config.ps1"


# Domain password. Comment this section so the script will prompt for the password.
# $domain_pwd = 'Passwor here' if you don't want to be prompted for the password.


# IP addresses of the nodes. It can be the Internal IP or external IP (natIP).
$ip_address1 = $(gcloud compute instances describe $node1 --format='get(networkInterfaces[0].networkIP)')
$ip_address2 = $(gcloud compute instances describe $node2 --format='get(networkInterfaces[0].networkIP)')
#$ip_address1 = $(gcloud compute instances describe $node1 --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
#$ip_address2 = $(gcloud compute instances describe $node2 --format='get(networkInterfaces[0].accessConfigs[0].natIP)')


## Run tests to verify that the PowerShell script ran succesfully
Write-Host "$(Get-Date) Testing that Availability Group was created succesfully"

## Validate that the Availability Group was created
## If using Pester, you can uncomment the "Discribe" and "It" sections below.
#Describe "Availability-Group-Created" {
#  It "Availability Group has two nodes that are synchronized" {
    
    $session_options = New-PSSessionOption -SkipCACheck -SkipCNCheck `
      -SkipRevocationCheck

    # Use SMO to query the DatabaseReplicaStates
    $results = Invoke-Command -ComputerName $ip_address1 -UseSSL `
      -Credential $cred -SessionOption $session_options `
      -ScriptBlock {
      
      param($name_ag)

      [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | 
        Out-Null
      $sql_server = New-Object `
        -TypeName Microsoft.SqlServer.Management.Smo.Server `
        -ArgumentList 'localhost'
      
      $sql_server.AvailabilityGroups[$($name_ag)].DatabaseReplicaStates | 
        Select-Object `
          AvailabilityReplicaServerName, `
          AvailabilityDatabaseName, `
          SynchronizationState
    } -ArgumentList $name_ag


    # Display the results (if not running within Pester)
    Write-Host "`r`n`r`nVerify that both nodes are syncronized"
    $results | FT

    # TEST: Should have two nodes and they should be in a "Synchronized" state
    [int]$results.Count | Should BeExactly 2
    [string]$results[0].SynchronizationState | Should Match "Synchronized"
    [string]$results[1].SynchronizationState | Should Match "Synchronized"
#  }
#}


## Validate that the Availability Group can switch nodes
#Describe "Availability-Group-can-switch-nodes" {
#  It "Availability Group can switch nodes" {

    # Connect to Listener and return @@SERVERNAME. Should match Node 1.
    $results = Invoke-Command -ComputerName $ip_address1 -UseSSL `
      -Credential $cred -SessionOption $session_options `
      -ScriptBlock { 
      param($name_ag_listener)

      Import-Module SQLPS -DisableNameChecking

      Invoke-Sqlcmd `
        -Query "SELECT ServerName = @@SERVERNAME" `
        -ServerInstance $name_ag_listener
    } -ArgumentList $name_ag_listener

    # Display the results (if not running within Pester)
    Write-Host "Before doing a failover $node1 should be the primary node"
    $results | FT

    # TEST: The @@SERVERNAME should be the name of Node 1
    [string]$results[0].ServerName | Should Match $node1

    Write-Host "*** Doing a failover to instance $node2 ***`r`n"

    # Switch to Node 2
    Invoke-Command -ComputerName $ip_address2 -UseSSL `
      -Credential $cred -SessionOption $session_options `
      -ScriptBlock {
      param($node2, $name_ag)

      Switch-SqlAvailabilityGroup `
        -Path "SQLSERVER:\SQL\$($node2)\DEFAULT\AvailabilityGroups\$($name_ag)"

        Start-Sleep 15
    } -ArgumentList $node2, $name_ag


    # Connect to Listener and return @@SERVERNAME. Should match Node 2.
    $results = Invoke-Command -ComputerName $ip_address2 -UseSSL `
      -Credential $cred -SessionOption $session_options `
      -ScriptBlock {
      param($name_ag_listener)

      Invoke-Sqlcmd `
        -Query "SELECT ServerName = @@SERVERNAME" `
        -ServerInstance $name_ag_listener
    } -ArgumentList $name_ag_listener

    # Display the results (if not running within Pester)
    Write-Host "After the failover $node2 should be the primary node"
    $results | FT

    # TEST: The @@SERVERNAME should be the name of Node 2
    [string]$results[0].ServerName | Should Match $node2

    # Switch to Node 1 again
    Invoke-Command -ComputerName $ip_address1 -UseSSL `
      -Credential $cred -SessionOption $session_options `
      -ScriptBlock {
      param($node1, $name_ag)

      Switch-SqlAvailabilityGroup `
        -Path "SQLSERVER:\SQL\$($node1)\DEFAULT\AvailabilityGroups\$($name_ag)"
    } -ArgumentList $node1, $name_ag
#  }
#}

