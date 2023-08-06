function Invoke-CreateDatabase {
    <#
       .SYNOPSIS
       Creates a new SQLite database file.
       .DESCRIPTION
       Creates a new SQLite database file.
       .PARAMETER database
       The config file object
    #>
    param([object]$config)
 
    $query = 'CREATE TABLE IF NOT EXISTS  [Fotos] ( 
       [Id] INTEGER PRIMARY KEY AUTOINCREMENT,       
       [HASH] NVARCHAR(50)  NOT NULL,  
       [BASENAME] NVARCHAR(256)  NOT NULL,  
       [EXTENSION] NVARCHAR(10) NOT NULL,  
       [CREATIONTIME] NVARCHAR(20) NOT NULL,  
       [FULLPATH] NVARCHAR(256) NOT NULL
    );'
    
    # Create the path if it does not exist
    $databaseFolder = Split-Path -Path $config.databasePath -Parent
    Write-Host "Checking database folder $databaseFolder" -ForegroundColor Green
    if (!(Test-Path -Path $databaseFolder)) {        
        Write-Host "Creating database folder $databaseFolder" -ForegroundColor Green
        New-Item -ItemType Directory -Force -Path $databaseFolder
    }

    Write-Host "Checking database $databaseFolder" -ForegroundColor Green

    [pscustomobject[]]$results = Invoke-SqliteQuery -Query $query -DataSource $config.databasePath
    
    if ($results.count -gt 0) {
        Write-Host "Numer of selected records:" $results.count -ForegroundColor Green
    }
    else {
        Write-Host "A fresh empty database :)" -ForegroundColor Yellow
    }
}
 