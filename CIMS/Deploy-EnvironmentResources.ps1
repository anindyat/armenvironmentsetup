
#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] [Parameter(Mandatory=$true)] $ApplicationId, #The ID of the application
    [string] [Parameter(Mandatory=$true)] $ApplicationSecret, #The "secret" key created for the application
    [string] [Parameter(Mandatory=$true)] $AadDirectoryId, #The Azure Active Directory ID
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName, #The place where resources will be listed
    [string] [Parameter(Mandatory=$false)][validateSet('CIMS', 'G3MS', 'BOTH')] $ApplicationDeployment = "BOTH",
    [string] $CIMSTemplateFile = 'CIMSEnvironment.json',
    [string] $CIMSTemplateParametersFile = 'CIMSEnvironment.stag.emea.parameters.json',
    [string] $G3MSTemplateFile = 'G3MSEnvironment.json',
    [string] $G3MSTemplateParametersFile = 'G3MSEnvironment.dev.naa.parameters.json',
	[boolean] $IsPublishCode = ($false),
	[string] $CIMSWebAppDirectory = "",
	[string] $G3MSWebAppDirectory = "",
	[string] $G3MSWebUIDirectory= "",
    [boolean] $IsCIMSSqlDep = ($false),
    [boolean] $IsG3MSSqlDep = ($false),
    [string] $CIMSSqlScriptDirectory = "", #E:\Otis\Databases-WithDeploymentScript\Databases\Databases
    [string] $G3MSSqlScriptDirectory = ""
)

#No restrictions; all Windows PowerShell scripts can be run
Set-ExecutionPolicy Unrestricted

$ScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition)

#Sets True or False if each of the files exists
$CIMSTemplateExists = Test-Path $CIMSTemplateFile
$G3MSTemplateExists = Test-Path $G3MSTemplateFile
$CIMSParametersExists = Test-Path $CIMSTemplateParametersFile
$G3MSParametersExists = Test-Path $G3MSTemplateParametersFile
$EnvironmentFilesExist = $CIMSTemplateExists -and $G3MSTemplateExists -and $CIMSParametersExists -and $G3MSParametersExists

#CIMS-related output files
$CIMSLogFileName = ".\CIMS_log-$(get-date -f yyyy-MM-ddTHH-mm-ss).txt"
$CIMSErrorFileName = ".\CIMS_error-$(get-date -f yyyy-MM-ddTHH-mm-ss).txt"
$CIMSOutputFileName = ".\CIMS_output-$(get-date -f yyyy-MM-ddTHH-mm-ss).txt"

#G3MS-related output files
$G3MSLogFileName = ".\G3MS_log-$(get-date -f yyyy-MM-ddTHH-mm-ss).txt"
$G3MSErrorFileName = ".\G3MS_error-$(get-date -f yyyy-MM-ddTHH-mm-ss).txt"
$G3MSOutputFileName = ".\G3MS_output-$(get-date -f yyyy-MM-ddTHH-mm-ss).txt"

#Clear Cached Credentials 
Get-AzureAccount | ForEach-Object { Remove-AzureAccount $_.ID -Force } 

#Obtain new credentials 
$secpasswd = ConvertTo-SecureString "$ApplicationSecret" -AsPlainText -Force
$subcreds = New-Object System.Management.Automation.PSCredential ("$ApplicationId", $secpasswd)
Login-AzureRmAccount -ServicePrincipal -Tenant $AadDirectoryId -Credential $subcreds 

#Check to see if Resource Group exists
$resourceGroupNameResult = Get-AzureRmResourceGroup -Name "$ResourceGroupName" -ErrorAction SilentlyContinue
if($resourceGroupNameResult -ne $null)
{
    "ResourceGroup exists $ResourceGroupName"

	$ApplicationDeployment = $ApplicationDeployment.ToUpper()

    if($EnvironmentFilesExist)
    {
	    # Determine which application to deploy
	    if (($ApplicationDeployment -eq "CIMS") -or ($ApplicationDeployment -eq "BOTH"))
	    #Deploys the CIMS template
	    {
		    New-AzureRmResourceGroupDeployment -Name "CIMS-$(get-date -f yyyy-MM-ddTHH-mm-ss)" -ResourceGroupName $ResourceGroupName `
									    -TemplateFile $CIMSTemplateFile -TemplateParameterFile $CIMSTemplateParametersFile `
									    -Force -Verbose 2>> $CIMSErrorFileName | Out-File $CIMSLogFileName -ErrorVariable ErrorMessages
		    if ($IsPublishCode){

		    $Result  = Find-AzureRmResource -ResourceType "microsoft.web/sites" -ResourceGroupName $ResourceGroupName -ResourceNameContains "CIMS-API"
		    $CIMSWebAppName = $Result.Name

	    & "$ScriptRoot\Deploy-AzureWebApp.ps1" `
		    -AppDirectory $CIMSWebAppDirectory `
		    -WebAppName $CIMSWebAppName `
		    -ResourceGroupName $ResourceGroupName
		    }

        #Deploys CIMS SQL Script
        if($IsCIMSSqlDep){
		    $CIMS_SqlServerObj  = Find-AzureRmResource -ResourceType "microsoft.sql/servers" -ResourceGroupName $ResourceGroupName -ResourceNameContains "CIMS"
            $CIMS_DatabaseObj= Find-AzureRmResource -ResourceType "microsoft.sql/servers/databases" -ResourceGroupName $ResourceGroupName -ResourceNameContains "CIMS"
            $CIMS_Database=$CIMS_DatabaseObj.Name.Split('/')
            $CIMS_SqlServerName=$CIMS_SqlServerObj.Name+".database.windows.net"
            $CIMS_DatabaseName=$CIMS_Database[1].ToString()
            $ScriptPath = Split-Path $MyInvocation.InvocationName
            & "$ScriptPath\Deploy-AzureSQL.ps1" -DBServer $CIMS_SqlServerName -DBName $CIMS_DatabaseName -DBUserName otisadmin -DBPassword 'P@$$w0rd' -DBScriptsPath $CIMSSqlScriptDirectory  
	    }
    }

	    #Deploys the G3MS template
	    if (($ApplicationDeployment -eq "G3MS") -or ($ApplicationDeployment -eq "BOTH"))
	    {
		    New-AzureRmResourceGroupDeployment -Name "G3MS-$(get-date -f yyyy-MM-ddTHH-mm-ss)" -ResourceGroupName $ResourceGroupName `
									    -TemplateFile $G3MSTemplateFile -TemplateParameterFile $G3MSTemplateParametersFile `
									    -Force -Verbose 2>> $G3MSErrorFileName | Out-File $G3MSLogFileName -ErrorVariable ErrorMessages
	    if ($IsPublishCode){

		    $Result  = Find-AzureRmResource -ResourceType "microsoft.web/sites" -ResourceGroupName $ResourceGroupName -ResourceNameContains "G3MS-API"
		    $G3MSWebAppName = $Result.Name

		    $Result1  = Find-AzureRmResource -ResourceType "microsoft.web/sites" -ResourceGroupName $ResourceGroupName -ResourceNameContains "G3MS-UI"
		    $G3MSWebUIName = $Result.Name

	    & "$ScriptRoot\Deploy-AzureWebApp.ps1" `
		    -AppDirectory $G3MSWebAppDirectory `
		    -WebAppName $G3MSWebAppName `
		    -ResourceGroupName $ResourceGroupName

	    & "$ScriptRoot\Deploy-AzureWebApp.ps1" `
		    -AppDirectory $G3MSWebUIDirectory `
		    -WebAppName $G3MSWebUIName `
		    -ResourceGroupName $ResourceGroupName

		    }
        #Deploys G3MS SQL Script
        if($IsG3MSSqlDep){
		    $G3MS_SqlServerObj  = Find-AzureRmResource -ResourceType "microsoft.sql/servers" -ResourceGroupName $ResourceGroupName -ResourceNameContains "G3MS"
            $G3MS_DatabaseObj= Find-AzureRmResource -ResourceType "microsoft.sql/servers/databases" -ResourceGroupName $ResourceGroupName -ResourceNameContains "G3MS"
            $G3MS_Database=$G3MS_DatabaseObj.Name.Split('/')
            $G3MS_SqlServerName=$G3MS_SqlServerObj.Name+".database.windows.net"
            $G3MS_DatabaseName=$G3MS_Database[1].ToString()
            $ScriptPath = Split-Path $MyInvocation.InvocationName
            & "$ScriptPath\Deploy-AzureSQL.ps1" -DBServer $G3MS_SqlServerName -DBName $G3MS_DatabaseName -DBUserName otisadmin -DBPassword 'P@$$w0rd' -DBScriptsPath $G3MSSqlScriptDirectory  
	    }
	
	    } 
    }

    #Else, one of the template or parameter files are missing
    else
    {
        "Missing template or parameter file." 
    }
}
else
{
    "Resource Group " + $ResourceGroupName + " Not Found"
}
