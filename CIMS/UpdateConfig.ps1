#
# UpdateConfig.ps1
#
param(
    [string] [Parameter(Mandatory=$true)] $AssemblyName, #ConfigFileName(Web or App)
    [string] [Parameter(Mandatory=$true)] $AppSettingsValues, #Appsettings Value to Change
    [string] [Parameter(Mandatory=$true)] $ConnectionStrings, #Connection String Value to Change
    [string] [Parameter(Mandatory=$true)] $AppDirectory, #Web Application Directory
    [string] [Parameter(Mandatory=$true)] $WebAppName, #Application Name on Azure
	[string] [Parameter(Mandatory=$true)] $ResourceGroupName #Azure Resource Group Name
)

$ScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition)
$filePath = "$ScriptRoot\web.config"
$appConfig=New-Object XML
$appConfig.load($filePath)
write-host $AppSettingsValues
[hashtable]$AppSettingsHash = ConvertFrom-StringData $AppSettingsValues
Write-Host "App Setting Hash:-"
$AppSettingsHash
write-host $ConnectionStrings
[hashtable]$ConnectionStringCollection = ConvertFrom-StringData $ConnectionStrings

#Update Config Value
$appSettings = $appConfig.GetElementsByTagName("appSettings")
foreach($appSetting in $appSettings.add){
    if($AppSettingsHash.ContainsKey($appSetting.key)){
        $appSetting.value = $AppSettingsHash[$appSetting.key]
    }
}

#Update Connection Value
Write-Host "updating connection strings"
$conStrings = $appConfig.GetElementsByTagName("connectionStrings")
foreach($conString in $conStrings.add){
    if($ConnectionStringCollection.ContainsKey($conString.name)){
        $conString.connectionString = $ConnectionStringCollection[$conString.name]
    }
    }
$appConfig.Save($filePath)

# Get publishing profile for the web app
$xml = [Xml](Get-AzureRmWebAppPublishingProfile -Name $webappname `
-ResourceGroupName $ResourceGroupName `
-OutputFile null)

# Extract connection information from publishing profile
$username = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@userName").value
$password = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@userPWD").value
$url = $xml.SelectNodes("//publishProfile[@publishMethod=`"FTP`"]/@publishUrl").value

# Upload files recursively 
Set-Location $AppDirectory
$webclient = New-Object -TypeName System.Net.WebClient
$webclient.Proxy = null
$webclient.Credentials = New-Object System.Net.NetworkCredential($username,$password)
$files = Get-ChildItem -Path $appdirectory -Recurse #Removed IsContainer condition
foreach ($file in $files)
{

	$relativepath = (Resolve-Path -Path $file.FullName -Relative).Replace(".\", "").Replace('\', '/')  
    $uri = New-Object System.Uri("$url/$relativepath")

    if($file.PSIsContainer)
    {
		"------For Directory " + $file.Name + "---------"
        $uri.AbsolutePath + "is Directory"
        $ftprequest = [System.Net.FtpWebRequest]::Create($uri);
		$ftprequest.Proxy = null
        $ftprequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
        $ftprequest.UseBinary = $true

        $ftprequest.Credentials = New-Object System.Net.NetworkCredential($username,$password)

        $response = $ftprequest.GetResponse();
        $response.StatusDescription
        continue
    }

	"------For FIle " + $file.Name + "---------"

    "Uploading to " + $uri.AbsoluteUri + " from "+ $file.FullName

    $webclient.UploadFile($uri, $file.FullName)
} 
$webclient.Dispose()


