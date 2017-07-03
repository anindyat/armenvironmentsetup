
#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage
################################## 
 
# Authenticate w/ Certificate   

#Get the publishSettingFile from the portal

# Get-AzurePublishSettingsFile 


##################################

Param(
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName,
    [string] [Parameter(Mandatory=$true)] $ResourceGroupLocation,
    [string] [Parameter(Mandatory=$true)] $deploymentName,
    [string] [Parameter(Mandatory=$true)] $ApplicationDeployment,
    [string] $LogFileName = ".\CIMS_log-$(get-date -f yyyy-MM-dd).txt",
    [string] $ErrorFileName = ".\CIMS_error-$(get-date -f yyyy-MM-dd).txt",
    [string] $OutputFileName = ".\CIMS_output-$(get-date -f yyyy-MM-dd).txt",
    [string] $TemplateFile = 'CIMSEnvironment.json',
    [string] $TemplateParametersFile = 'CIMSEnvironment.parameters.json'
)
 
Set-ExecutionPolicy Unrestricted
#$aadClientId = 'f712a560-e91a-4fa9-a366-441989bb230e'
#$aadClientSecret = '2Z8RCc/nG4YihxXeMgaauiwFAs48MgZU103wgoDgM3M='
#$aadTenantId = 'a1955e28-2936-4d88-9b2b-549fea819975'

$aadClientId = '77d30e9a-a1d5-42e6-a4b1-d8009b1fbbd7'
$aadClientSecret = 'AKKbp0VTYj1yDhwURVGLAB/FeYKS6aNA7lMOyWbCQEw='
$aadTenantId = '3df212f7-caab-434b-bf95-980c5f161c43'

# Clear Cached Credentials 
Get-AzureAccount | ForEach-Object { Remove-AzureAccount $_.ID -Force } 

$secpasswd = ConvertTo-SecureString "$aadClientSecret" -AsPlainText -Force
$subcreds = New-Object System.Management.Automation.PSCredential ("$aadClientId", $secpasswd)
Login-AzureRmAccount -ServicePrincipal -Tenant $aadTenantId -Credential $subcreds 

#Checking if RG exists
$resourceGroupNameResult = Get-AzureRmResourceGroup -Name "$ResourceGroupName" -ErrorAction SilentlyContinue
#$resourceGroupNameResult = Get-AzureRmResource -Name "$ServiceName" -ResourceGroupName "$ResourceGroupName" -ErrorAction SilentlyContinue
if($resourceGroupNameResult -ne $null)
{
    Write-Verbose "ResourceGroup exists $ResourceGroupName"
}
else
{
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -ErrorAction SilentlyContinue
}

# Determine which application to deploy
if($ApplicationDeployment.ToLower() -eq "cims") 
{
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName `
								       -TemplateFile "CIMSEnvironment.json" -TemplateParameterFile "CIMSEnvironment.parameters.json" `
								       -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessages 
}
elseif($ApplicationDeployment.ToLower() -eq "g3ms")
{
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName `
								       -TemplateFile "G3MSEnvironment.json" -TemplateParameterFile "G3MSEnvironment.parameters.json" `
								       -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessages 
}
else
{
    New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $ResourceGroupName `
								       -TemplateFile "CIMSEnvironment.json" -TemplateParameterFile "CIMSEnvironment.parameters.json" `
								       -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessagess

    New-AzureRmResourceGroupDeployment -Name "G3MS-$(get-date -f yyyy-MM-dd)" -ResourceGroupName $ResourceGroupName `
								       -TemplateFile "G3MSEnvironment.json" -TemplateParameterFile "G3MSEnvironment.parameters.json" `
								       -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessages
}

#Import-Module "C:\Program Files (x86)\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Azure.psd1"

#New-AzureRmResourceGroupDeployment -Name $ResourceGroupName -TemplateFile deploymentTemplate.json -ResourceGroupName $ResourceGroupName 
#New-AzureRmResourceGroupDeployment -Name "ggjgfsdgfsjag" -ResourceGroupName $ResourceGroupName `
#								   -TemplateFile "CIMSEnvironment.json" -TemplateParameterFile "CIMSEnvironment.parameters.json" `
#								   -Force -Verbose 2>> $ErrorFileName | Out-File $LogFileName -ErrorVariable ErrorMessages
