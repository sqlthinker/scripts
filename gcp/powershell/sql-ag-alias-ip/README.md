## Creating a SQL Server Availability Group in GCP using Alias IP Ranges

The following PowerShell scripts will help you setup a SQL Server Availability Group using [Alias IP Ranges](https://cloud.google.com/compute/docs/alias-ip/) in GCP. Alias IP lets you assign a range of IPs to a instance. To create an Availability Group we need two extra IPs per node (one for the Windows Failover Cluster and another for the Listener). 

With Alias IP Ranges currently we can only use a /24 CIDR as aliased IPs which give us 254 extra IPs per node, but we only use two of those IPs. If you don't like the fact that you cannot use the other 252 IPs you can still use the original version of the scripts that can be found [here](https://github.com/GoogleCloudPlatform/dotnet-docs-samples/tree/master/compute/sqlserver/powershell). The main different between the two versions of the scripts is that with Alias IP you don't need to create the GCP routes to route traffic from the two extra IPs back to the node and don't need to modify the Netmask in the nodes.

  * [parameters-config.ps1](parameters-config.ps1) - Specify the parameters that are used by the other scripts.
  * [create-sql-instance-availability-group.ps1](create-sql-instance-availability-group.ps1) - **Usually this is the only script that needs to be run**. It does the following steps:
      1. Creates two SQL Server instances
      2. Adds the two instances to a Windows AD domain
      3. Creates a Windows Server Failover Cluster (WSFC)
      4. Creates a SQL Server Availability Group
  * [create-availability-group.ps1](create-availability-group.ps1) - Script to create the Availability Group. It is called by the script *create-sql-instance-availability-group.ps1*.
  * [create-sql-instance-availability-group-prerequisites.ps1](create-sql-instance-availability-group-prerequisites.ps1) - (Optional) Set up the pre-requisites needed to create an Availability Group:
     1. Creates a Custom Network in GCP
     2. Creates firewall rules for WinRM and RDP
     3. Creates a Windows AD domain with one domain controller
  * [create-sql-instance-availability-group-cleanup.ps1](create-sql-instance-availability-group-cleanup.ps1) - (Optional) Delete the SQL Server instances, the domain controller and the custom network. *WARNING: Use with caution. Use in cases where you are just testing the scripts*.
  * [create-sql-instance-availability-group.Tests.ps1](create-sql-instance-availability-group.Tests.ps1) - (Optional) Use Pester to unit test the scripts.
