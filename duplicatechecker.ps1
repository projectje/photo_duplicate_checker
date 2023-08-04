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

Import-Module PSSQLite

# -------------- configuration --------------------

#
# The location for a temporary database, if you remove or move files in your master folder you
# can delete this database and it will be recreated. You can also delete it each time you run the script.
#

$curDir = Get-Location
$database = "$curDir\PHOTOS.db"

# The masterfolders are the definitive folders where the photos are stored
# Listing them individually is handy to process them in parallel

$masterFolder = @()
$masterFolder += '\\Spock\photo\1976'
$masterFolder += '\\Spock\photo\1978'
$masterFolder += '\\Spock\photo\1979'
$masterFolder += '\\Spock\photo\1993'
$masterFolder += '\\Spock\photo\1999'
$masterFolder += '\\Spock\photo\2000'
$masterFolder += '\\Spock\photo\2001'
$masterFolder += '\\Spock\photo\2002'
$masterFolder += '\\Spock\photo\2003'
$masterFolder += '\\Spock\photo\2004'
$masterFolder += '\\Spock\photo\2005'
$masterFolder += '\\Spock\photo\2006'
$masterFolder += '\\Spock\photo\2007'
$masterFolder += '\\Spock\photo\2008'
$masterFolder += '\\Spock\photo\2009'
$masterFolder += '\\Spock\photo\2010'
$masterFolder += '\\Spock\photo\2011'
$masterFolder += '\\Spock\photo\2012'
$masterFolder += '\\Spock\photo\2013'
$masterFolder += '\\Spock\photo\2014'
$masterFolder += '\\Spock\photo\2015'
$masterFolder += '\\Spock\photo\2016'
$masterFolder += '\\Spock\photo\2017'
$masterFolder += '\\Spock\photo\2018'
$masterFolder += '\\Spock\photo\2019'
$masterFolder += '\\Spock\photo\2020'
$masterFolder += '\\Spock\photo\2021'
$masterFolder += '\\Spock\photo\2022'   
$masterFolder += '\\Spock\photo\2023'

#
# filename for duplicates in the master folder
#

$masterFolderDuplicates = "$curDir\masterFolderDuplicates.txt"

#
# filename for duplicates in the incoming folder
# 

$incomingFolderDuplicates = "$curDir\incomingFolderDuplicates.txt"


# -------------- functions --------------------

function CreateDatabase() {
   <#
      .SYNOPSIS
      Creates a new SQLite database file.
      .DESCRIPTION
      Creates a new SQLite database file.
      .PARAMETER database
      The path to the SQLite database file.
      .EXAMPLE
      CreateDatabase -database "C:\temp\MyDB.sqlite3"
      .NOTES   
   #>
   param([string]$database)

   $query = 'CREATE TABLE IF NOT EXISTS  [Fotos] ( 
      [Id] INTEGER PRIMARY KEY AUTOINCREMENT,       
      [HASH] NVARCHAR(50)  NOT NULL,  
      [BASENAME] NVARCHAR(256)  NOT NULL,  
      [EXTENSION] NVARCHAR(10) NOT NULL,  
      [CREATIONTIME] NVARCHAR(20) NOT NULL,  
      [FULLPATH] NVARCHAR(256) NOT NULL
   );'
   
   [pscustomobject[]]$results = Invoke-SqliteQuery -Query $query -DataSource $database
   
   if ($results.count -gt 0) {
      Write-Host "Numer of selected records:" $results.count
   }
   else {
      Write-Host "No records found"
   }
}


function ParseMasterFotoFolder {
   param(
      [string] $database, 
      [string[]] $masterFolder
      )

   CreateDatabase -database $database

   $masterFolder | ForEach-Object -Parallel { 

      function sqlite3_escape_string($value) {
   
         if ([string]::IsNullOrEmpty($value)) {
            Write-Error 'empty'
            return " "
         }
   
         $escapedValue = ''
         $value.ToCharArray() | ForEach-Object {
            if ($_ -eq "'") {
               $escapedValue += "''"
            }
            else {
               $escapedValue += $_
            }
         }
         return $escapedValue
      }

      function TraverseDir {
         <#
         .SYNOPSIS
         Traverses a directory and inserts the files into the database.
         .DESCRIPTION
         Traverses a directory and inserts the files into the database.
         .PARAMETER directory
         The path to the directory.
         .EXAMPLE
         TraverseDir -directory "C:\temp"
         .NOTES   
      #>
         param([string]$directory, [string]$database)
   
         if ([string]::IsNullOrEmpty($database)) {
            Write-Error 'Database path is empty or null'
            return
         }
   
         $items = Get-ChildItem $directory
         foreach ($item in $items) {
            if ($item.PSIsContainer) {
               #Write-Host $item.FullName
               TraverseDir -directory $item.FullName -database $database
            }
            else {
               # todo: runthrough all entries in database to verify if the entries still exist otherwise remove them
               # todo: runthrough all entries in database to check for duplicate fullpaths if so remove them
   
               # find if file is already in database
               $escapedPath = sqlite3_escape_string($item.FullName)
               $query = "select * from [Fotos] where [FULLPATH] = '$escapedPath'"
               [pscustomobject[]]$results = Invoke-SqliteQuery -Query $query -DataSource $database
   
               if ($results.count -eq 0) {               
                  # file is not in database, insert it
                  Write-Host "inserting new photo" $item.FullName
                                                
                  $escapedPath = sqlite3_escape_string($item.FullName)
                  $escapedBaseName = sqlite3_escape_string($item.BaseName)
                  $escapedExtension = sqlite3_escape_string($item.Extension)
                  $escapedCreationTime = sqlite3_escape_string($item.CreationTime.ToString())
                  $escapedHash = Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256 | Select-Object -ExpandProperty Hash   
   
                  $query = "INSERT INTO [Fotos] ([HASH], [BASENAME], [EXTENSION], [CREATIONTIME], [FULLPATH]) 
                     VALUES ('$escapedHash', '$escapedBaseName', '$escapedExtension', '$escapedCreationTime', '$escapedPath')"
                                                         
                  Invoke-SqliteQuery -Query $query -DataSource $database
               }           
            }
         }
      }


      $curDir = Get-Location
      $database = "$curDir\MyDB.sqlite3"

      TraverseDir -directory $_ -database $($using:database)   
   }  
}



function MasterDuplicates {

   param([string] $masterFolderDuplicates, [string] $database)

   # find duplicates
   $query = "select hash, fullpath from fotos where hash in (
   SELECT hash FROM Fotos GROUP BY hash HAVING COUNT(hash) > 1
   ) order by hash, fullpath"
   [pscustomobject[]]$results = Invoke-SqliteQuery -Query $query -DataSource $database

   $results | ConvertTo-Csv | Out-File $masterFolderDuplicates

   # for every set of duplicates with the same hash  keep only one and move the duplicates
   # to a duplicate folder
   <#
   $previousHash = ''
   $previousFullPath = ''
   foreach ($file in $results) {
      $hash = $file.hash
      $fullPath = $file.fullpath

      if ($hash -ne $previousHash) {
         # next set of duplicates, first file so the one we keep
         $previousHash = $hash
         $previousFullPath = $fullPath
         $first = $true
      }
      else {
         if ($first) {
            $first = $false
            $previousFullPath = $fullPath
         }
         else {
            $previousFullPath
            $fullPath
            $first = $true
         }
      }

   }

   $duplicateFolder = "$curDir\duplicate"
   if (!(Test-Path $duplicateFolder)) {
      New-Item -ItemType Directory -Force -Path $duplicateFolder
   }  
   #>
}

# -------------- RUN --------------------

ParseMasterFotoFolder -database $database -masterFolder $masterFolder
MasterDuplicates -masterFolderDuplicates $masterFolderDuplicates -database $database

