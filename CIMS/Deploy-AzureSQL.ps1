Param (

    [Parameter(Mandatory=$True)]
    [String]
    $DBServer,

    [Parameter(Mandatory=$True)]
    [String]
    $DBName,

    [Parameter(Mandatory=$True)]
    [String]
    $DBUserName,

    [Parameter(Mandatory=$True)]
    [String]
    $DBPassword,

    [Parameter(Mandatory=$True)]
    [String]
    $DBScriptsPath,

    [Parameter(Mandatory=$False)]
    [String]
    $FilesFilter = "*.sql"
)

function Import-Module-SQLPS {
    push-location
    import-module sqlps 3>&1 | out-null
    pop-location
}

Import-Module-SQLPS

$files = Get-ChildItem $DBScriptsPath -Filter $FilesFilter

foreach($file in $files)
{
    Write-Host $file
    Invoke-Sqlcmd -ServerInstance $DBServer -Database $DBName -Username $DBUserName -Password $DBPassword -Inputfile $DBScriptsPath\$file
}

