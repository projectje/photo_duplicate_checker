
function Invoke-ParseMasterFotoFolder {
   param(
      [object] $config
   )
 
   $database = $config.databasePath
 
   $startYear = $config.masterFolder.startYear
   $endYear = (Get-Date).Year
 
   # add a path for each year
   $masterFolder = @()
   for ($i = $startYear; $i -le $endYear; $i++) {
      $masterFolder += Join-Path -Path $config.masterFolder.rootFolder -ChildPath $i  
   }
   # add a path for each special folder
   foreach ($specialFolder in $config.masterFolder.specialFolder) {
      $masterFolder += Join-Path $config.masterFolder.rootFolder -ChildPath $specialFolder.folder
   }
   if ($config.masterFolder.parse -eq $true) {
       
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
    
            if ([string]::IsNullOrEmpty($directory)) {
               Write-Error 'Directory path is empty or null'
               return
            }

            if (!(Test-Path -Path $directory)) {
               Write-Host "Directory $directory does not exist so skipping" -ForegroundColor Yellow
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
 
         TraverseDir -directory $_ -database $($using:database)   
      }
   }  
}

function Get-MasterDuplicatesReport {

   param([object] $config)

   # Create the path if it does not exist

   Write-Host "Checking report folder " $config.reportPath -ForegroundColor Green
   if (!(Test-Path -Path $config.reportPath)) {        
      Write-Host "Creating report folder " $config.reportPath -ForegroundColor Green
      New-Item -ItemType Directory -Force -Path $config.reportPath  -ErrorAction SilentlyContinue
   }

   # find duplicates
   $query = "select hash, fullpath from fotos where hash in (
   SELECT hash FROM Fotos GROUP BY hash HAVING COUNT(hash) > 1
   ) order by hash, fullpath"

   [pscustomobject[]]$results = Invoke-SqliteQuery -Query $query -DataSource $config.databasePath

   $reportPath = Join-Path $config.reportPath -ChildPath "masterDuplicates.csv"

   $results | ConvertTo-Csv | Out-File $reportPath
}

function Invoke-MoveMasterDuplicates {

   param([object] $config)

   # find duplicates
   $query = "select hash, fullpath from fotos where hash in (
      SELECT hash FROM Fotos GROUP BY hash HAVING COUNT(hash) > 1
      ) order by hash, fullpath"
   
   [pscustomobject[]]$results = Invoke-SqliteQuery -Query $query -DataSource $config.databasePath
   
   if ($results.count -eq 0) {
      Write-Host "No duplicates found" -ForegroundColor Green
      return
   }

   $previousHash = ''
   foreach ($file in $results) {
      $hash = $file.hash
      if ($hash -ne $previousHash) {
         $previousHash = $hash
         write-host $hash " KEEP " $file.fullpath -ForegroundColor green
      }
      else {         
         $duplicateFileTarget = Join-Path $config.masterFolder.duplicatesFolder -ChildPath ($file.fullpath.Replace($config.masterFolder.rootFolder, ''))

         # Create the path if it does not exist
         $duplicateFolderTarget = Split-Path -Path $duplicateFileTarget -Parent
         #Write-Host "Checking duplicate folder $duplicateFolderTarget" -ForegroundColor Green
         if (!(Test-Path -Path $duplicateFolderTarget)) {        
            #Write-Host "Creating duplicate folder $duplicateFolderTarget" -ForegroundColor Green
            New-Item -ItemType Directory -Force -Path $duplicateFolderTarget -ErrorAction SilentlyContinue
         }

         # move the duplicate file     
         write-host $hash " MOVE " $file.fullpath -ForegroundColor yellow
         write-host $hash "Move-Item -Path" $file.fullpath " -Destination " $duplicateFileTarget -ForegroundColor yellow         
      }
   }
}
