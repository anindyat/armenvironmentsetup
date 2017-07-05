
#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] [Parameter(Mandatory=$true)] $ApplicationId, #The ID of the application
    [string] [Parameter(Mandatory=$true)] $ApplicationSecret, #The "secret" key created for the application
    [string] [Parameter(Mandatory=$true)] $AadDirectoryId, #The Azure Active Directory ID
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName, #The place where resources will be listed
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation, #The location where the Resource Group will be created
    [string] [Parameter(Mandatory=$false)][validateSet('CIMS', 'G3MS', 'BOTH')] $ApplicationDeployment = "CIMS",
    [string] $CIMSTemplateFile = 'CIMSEnvironment.json',
    [string] $CIMSTemplateParametersFile = 'CIMSEnvironment.prod.emea.parameters.json',
    [string] $G3MSTemplateFile = 'G3MSEnvironment.json',
    [string] $G3MSTemplateParametersFile = 'G3MSEnvironment.prod.emea.parameters.json'
)

#CIMS-related output files
$CIMSLogFileName = ".\OutputFiles\CIMS_log-$(get-date -f yyyy-MM-dd).txt"
$CIMSErrorFileName = ".\OutputFiles\CIMS_error-$(get-date -f yyyy-MM-dd).txt"
$CIMSOutputFileName = ".\OutputFiles\CIMS_output-$(get-date -f yyyy-MM-dd).txt"

#G3MS-related output files
$G3MSLogFileName = ".\OutputFiles\G3MS_log-$(get-date -f yyyy-MM-dd).txt"
$G3MSErrorFileName = ".\OutputFiles\G3MS_error-$(get-date -f yyyy-MM-dd).txt"
$G3MSOutputFileName = ".\OutputFiles\G3MS_output-$(get-date -f yyyy-MM-dd).txt"
 
Set-ExecutionPolicy Unrestricted

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
    Write-Verbose "ResourceGroup exists $ResourceGroupName"
}
else
{
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -ErrorAction SilentlyContinue
}

# Determine which application to deploy
switch ($ApplicationDeployment.ToLower())
{ 
    #Deploys the CIMS template
    "CIMS" {
        New-AzureRmResourceGroupDeployment -Name "CIMS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								    -TemplateFile $CIMSTemplateFile -TemplateParameterFile $CIMSTemplateParametersFile `
								    -Force -Verbose 2>> $CIMSErrorFileName | Out-File $CIMSLogFileName -ErrorVariable ErrorMessages
    } 

    #Deploys the G3MS template
    "G3MS" {
        New-AzureRmResourceGroupDeployment -Name "G3MS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								    -TemplateFile $G3MSTemplateFile -TemplateParameterFile $G3MSTemplateParametersFile `
								    -Force -Verbose 2>> $G3MSErrorFileName | Out-File $G3MSLogFileName -ErrorVariable ErrorMessages 
    } 

    #Deploys both the CIMS & G3MS templates
    "BOTH" {
        New-AzureRmResourceGroupDeployment -Name "CIMS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								    -TemplateFile $CIMSTemplateFile -TemplateParameterFile $CIMSTemplateParametersFile `
								    -Force -Verbose 2>> $CIMSErrorFileName | Out-File $CIMSLogFileName -ErrorVariable ErrorMessagess

        New-AzureRmResourceGroupDeployment -Name "G3MS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								    -TemplateFile $G3MSTemplateFile -TemplateParameterFile $G3MSTemplateParametersFile `
								    -Force -Verbose 2>> $G3MSErrorFileName | Out-File $G3MSLogFileName -ErrorVariable ErrorMessages
    }
}
