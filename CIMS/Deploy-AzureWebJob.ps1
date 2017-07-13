#
# WebJobDeployment.ps1
#
param(
	    [string] [Parameter(Mandatory=$true)] $WebJobName, #WebJob Name
        [string] [Parameter(Mandatory=$true)] $WebJobType, #Web Job Type (Continuous or Tiggered)
        [string] [Parameter(Mandatory=$true)] $JobDirectory, #Web Job Location
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


#Web Job Folder Creation Start
$UploadFolder = "App_Data\jobs" + "\" + $JobType+ "\"+ $JobName
$ResultPath = $UploadFolder.Split("\")

    foreach($item in $ResultPath)
    {
        $uri = New-Object System.Uri("$url/$item")
        try
        {
            
            $ftprequest = [System.Net.FtpWebRequest]::Create($uri);
            $ftprequest.Proxy = null
            $ftprequest.Method = [System.Net.WebRequestMethods+Ftp]::MakeDirectory
            $ftprequest.UseBinary = $true
            $ftprequest.Credentials = New-Object System.Net.NetworkCredential($username,$password)
            $url = $uri
            $response = $ftprequest.GetResponse();
            $response.StatusDescription
        }
        catch [Net.WebException]
        {
            try {
                #if there was an error returned, check if folder already existed on server
                $checkDirectory = [System.Net.WebRequest]::Create($uri);
                $checkDirectory.proxy= null
                $checkDirectory.Credentials = New-Object System.Net.NetworkCredential($username,$password)
                $checkDirectory.Method = [System.Net.WebRequestMethods+FTP]::PrintWorkingDirectory;
                $response = $checkDirectory.GetResponse();
                #folder already exists!
            }
            catch [Net.WebException] {
                #if the folder didn't exist
            }
        }
    }

# Upload files recursively 
Set-Location $JobDirectory
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








	
