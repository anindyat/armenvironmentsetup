
#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage
################################## 
 
# Authenticate w/ Certificate   

#Get the publishSettingFile from the portal

# Get-AzurePublishSettingsFile 


##################################

Param(
    [string] [Parameter(Mandatory=$true)] $aadClientId,
    [string] [Parameter(Mandatory=$true)] $aadClientSecret,
    [string] [Parameter(Mandatory=$true)] $aadTenantId,
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName,
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] [Parameter(Mandatory=$false)][validateSet('CIMS', 'G3MS', 'Both')] $ApplicationDeployment = "CIMS",
    [string] $LogFileName = ".\CIMS_log-$(get-date -f yyyy-MM-dd).txt",
    [string] $ErrorFileName = ".\CIMS_error-$(get-date -f yyyy-MM-dd).txt",
    [string] $OutputFileName = ".\CIMS_output-$(get-date -f yyyy-MM-dd).txt",
    [string] $TemplateFile = 'CIMSEnvironment.json',
    [string] $TemplateParametersFile = 'CIMSEnvironment.parameters.json'
)
 
Set-ExecutionPolicy Unrestricted

# Clear Cached Credentials 
Get-AzureAccount | ForEach-Object { Remove-AzureAccount $_.ID -Force } 

$secpasswd = ConvertTo-SecureString "$aadClientSecret" -AsPlainText -Force
$subcreds = New-Object System.Management.Automation.PSCredential ("$aadClientId", $secpasswd)
Login-AzureRmAccount -ServicePrincipal -Tenant $aadTenantId -Credential $subcreds 

#Checking if RG exists
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
        "cims" {
            New-AzureRmResourceGroupDeployment -Name "CIMS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								       -TemplateFile "CIMSEnvironment.json" -TemplateParameterFile "CIMSEnvironment.parameters.json" `
								       -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessages
        } 
        "g3ms" {
            New-AzureRmResourceGroupDeployment -Name "G3MS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								       -TemplateFile "G3MSEnvironment.json" -TemplateParameterFile "G3MSEnvironment.parameters.json" `
								       -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessages 
        } 
        "both" {
            New-AzureRmResourceGroupDeployment -Name "CIMS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								       -TemplateFile "CIMSEnvironment.json" -TemplateParameterFile "CIMSEnvironment.parameters.json" `
								       -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessagess

            New-AzureRmResourceGroupDeployment -Name "G3MS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								       -TemplateFile "G3MSEnvironment.json" -TemplateParameterFile "G3MSEnvironment.parameters.json" `
								       -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessages
        }
    }
