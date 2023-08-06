<#
   .SYNOPSIS
   This script checks for duplicates of photos in a master target photo folder, checks for duplicates
   in an incoming folder and can create a staging folder for photos in your incoming folder
   as proposal to add in your master folder.
   .DESCRIPTION
   1. You have one folder that contains your masterset of foto's. This is your master folder.
      The script will never write or mutate anything in this master folder
   2. You have an incoming folder in which you dump folders of photos that you want to add to your master folder.
   a. The script will check for duplicates in your master folder
   b. The script will check for duplicates in your incoming folder
   c. The script will create 
      c1. a staging folder in your incoming folder with the photos that are not in your master folder
         so that you can copy them manually in your master folder, it will do this based on the pattern
         year/year-month-day
      c2. a dupliate folder in your incoming folder with the photos that are already in your master folder   
#>
# Load modules
(Get-ChildItem -Path "$PSScriptRoot\Modules" -Recurse -Filter '*.psm1' -Verbose).FullName | ForEach-Object { Import-Module $_ -Force }

# Load PSSqlite module ( if not present install it with Install-Module PSSQLite)
Import-Module PSSQLite

# Run
$config = Get-JsonFile
Invoke-CreateDatabase -config $config
Invoke-ParseMasterFotoFolder -config $config
Get-MasterDuplicatesReport -config $config
Invoke-MoveMasterDuplicates -config $config

