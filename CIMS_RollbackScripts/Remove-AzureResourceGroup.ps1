#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] [Parameter(Mandatory=$true)] $ApplicationId, #The ID of the application
    [string] [Parameter(Mandatory=$true)] $ApplicationSecret, #The "secret" key created for the application
    [string] [Parameter(Mandatory=$true)] $AadDirectoryId, #The Azure Active Directory ID
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName, #The place where resources will be deleted from
    [string] $RGCleanupTemplateFile = '../CIMS_RollbackScripts/azuredeploy.json'
)

#No restrictions; all Windows PowerShell scripts can be run
Set-ExecutionPolicy Unrestricted

$ScriptRoot = (Split-Path -parent $MyInvocation.MyCommand.Definition)

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
	New-AzureRmResourceGroupDeployment -Name "ResourceRemoval-$(get-date -f yyyy-MM-ddTHH-mm-ss)" -ResourceGroupName $ResourceGroupName `
								       -Mode Complete -TemplateFile $RGCleanupTemplateFile -Force -Verbose
}

else
{
    "Resource Group " + $ResourceGroupName + " Not Found"
}