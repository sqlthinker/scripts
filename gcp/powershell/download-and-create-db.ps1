#Requires -Version 5
<#
.SYNOPSIS
  Creates a SQL Server instance in GCP and restores a database

  .DESCRIPTION
  Creates database by restoring from a backup. This could be used as the startup script
  for a SQL Server GCP instance. This sample code uses the AdventureWorks2014 database
  but you can replace it with you own database that is located somewhere in the network.

.NOTES
  AUTHOR: Anibal Santiago - @SQLThinker
#>

### Specify the information about the database to restore
$db_name            = "AdventureWorks2014"            # Name of the database.
$db_zip_url         = "https://msftdbprodsamples.codeplex.com/downloads/get/880661"  # URL to download the database backup.
$db_zip_backup_file = "AdventureWorks2014.bak.zip"    # Name to give to the downloaded backup file. Must be a Zip file.
$sql_data           = "C:\SQLData"                    # Directory to store the data 
$sql_log            = "C:\SQLLog"                     # Directory to store the transaction log 
$sql_backup         = "C:\SQLBackup"                  # Directory to download the zipped backup file
$drop_db            = $True                           # Drop the database if it exits: $True=Drop; $FALSE:Don't Drop

$ErrorActionPreference = "Stop"

# Import the SQL Server module
Import-Module SQLPS -DisableNameChecking

# Create a SQL Server object
$sql_server = "localhost"
$obj_server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $sql_server

# If the database exist and we dont't want to drop it, we skip everything
if ( $obj_server.Databases[$db_name] -and !($drop_db) ) {
  Write-Host "$(Get-Date) The database $db_name already exist and will not be dropped"
}
else {

  # Create directories for database and backup files
  Write-Host "$(Get-Date) Creating folders: $sql_data; $sql_log; $sql_backup"
  if (!(Test-Path -Path $sql_data   )) { New-item -ItemType Directory $sql_data   | Out-Null }
  if (!(Test-Path -Path $sql_log    )) { New-item -ItemType Directory $sql_log    | Out-Null }
  if (!(Test-Path -Path $sql_backup )) { New-item -ItemType Directory $sql_backup | Out-Null }

  # Download the zip backup file
  $zip_download = $sql_backup + "\" + $db_zip_backup_file
  Write-Host "$(Get-Date) Downloading file from URL: $db_zip_url"
  Invoke-WebRequest -Uri $db_zip_url -OutFile $zip_download

  # Uncompress the zip backup file by means of copying the file out of the zip file
  Write-Host "$(Get-Date) Uncompressing file"
  $shell = new-object -com shell.application
  $zip = $shell.NameSpace($zip_download)
  $item = $zip.items() | Select-Object -Last 1
  $shell.NameSpace($sql_backup).CopyHere($item, 0x14)

  # Drop the database if it exists
  if ( $obj_server.Databases[$db_name] ) {
    Write-Host "$(Get-Date) Dropping the database $db_name"
    $obj_server.Databases[$db_name].Drop()
  }

  # Create a backup restore object
  $backup_file = $sql_backup + "\" + $item.Name
  $obj_restore = New-Object Microsoft.SqlServer.Management.Smo.Restore
  $obj_restore.Database = $db_name
  $obj_restore.Devices.AddDevice($backup_file, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)

  # Get a list of files in the backup file
  $file_list = $obj_restore.ReadFileList($obj_server)

  # Loop through the list of files and find their new location
  foreach($file in $file_list)
  {
    if ( $file.Type -eq 'D' ) {
      $relocate_file = Join-Path $sql_data (Split-Path $file.PhysicalName -Leaf)
    }
    else {
      $relocate_file = Join-Path $sql_log (Split-Path $file.PhysicalName -Leaf)
    }

    # Create a relocated file object with the new location of the database files
    $obj_relocate_file = $null
    $obj_relocate_file = New-Object Microsoft.SqlServer.Management.Smo.RelocateFile($file.LogicalName, $relocate_file)

    # Add the relocated file object to the backup restore object
    $obj_restore.RelocateFiles.Add($obj_relocate_file) | out-null;
  }

  # Restore the database
  Write-Host "$(Get-Date) Restoring database $db_name from backup file"
  $obj_restore.SqlRestore($obj_server);
  Write-Host "$(Get-Date) Restore of database $db_name finished"
}
