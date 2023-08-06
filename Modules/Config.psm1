#
# will check for appsettings.json or appsettings.ini in root folder
#

function Get-JsonConfigFilePath
{    
    $rootFolder = Split-Path -Path $MyInvocation.PSScriptRoot -Parent

    # test if in the root a file appsettings-development.json exists
    $jsonFile = Join-Path -Path $rootFolder -ChildPath 'appsettings-development.json'
    if (Test-Path -Path $jsonFile) {
        return $jsonFile
    }

    # test if in the root folder config a file appsettings-development.json exists
    $jsonFile = Join-Path -Path $rootFolder -ChildPath 'Config'
    $jsonFile = Join-Path -Path $jsonFile -ChildPath 'appsettings-development.json'
    if (Test-Path -Path $jsonFile) {
        return $jsonFile
    }

    # test if in the root a file appsettings.json exists
    $jsonFile = Join-Path -Path $rootFolder -ChildPath 'appsettings.json'
    if (Test-Path -Path $jsonFile) {
        return $jsonFile
    }

    # test if in the root folder config a file appsettings.json exists
    $jsonFile = Join-Path -Path $rootFolder -ChildPath 'Config'
    $jsonFile = Join-Path -Path $jsonFile -ChildPath 'appsettings.json'
    if (Test-Path -Path $jsonFile) {
        return $jsonFile
    }

}

function Get-JsonFile {

    $path =  Get-JsonConfigFilePath
    if ([string]::IsNullOrEmpty($path)) {
        Write-Error 'No config file found'
        return
    }

    write-host "reading config from $path" -ForegroundColor Green

    $configData = Get-Content $path -Raw 
    $config = ConvertFrom-Json -InputObject $configData

    return $config
}   

