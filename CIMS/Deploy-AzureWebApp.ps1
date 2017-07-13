#
# WebAppDeployment.ps1
#
Param(
    [string] [Parameter(Mandatory=$true)] $AppDirectory, #Web Application Directory
    [string] [Parameter(Mandatory=$true)] $WebAppName, #Application Name on Azure
	[string] [Parameter(Mandatory=$true)] $ResourceGroupName #Azure Resource Group Name
)

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
