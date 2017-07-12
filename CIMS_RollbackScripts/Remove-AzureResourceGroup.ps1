#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage

Param(
    [string] [Parameter(Mandatory=$true)] $ApplicationId, #The ID of the application
    [string] [Parameter(Mandatory=$true)] $ApplicationSecret, #The "secret" key created for the application
    [string] [Parameter(Mandatory=$true)] $AadDirectoryId, #The Azure Active Directory ID
    [string] [Parameter(Mandatory=$true)] $ResourceGroupName, #The place where resources will be deleted from
    [string] [Parameter(Mandatory=$false)][validateSet('CIMS', 'G3MS', 'BOTH')] $ApplicationRemoval = "BOTH",
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

    # Encloses the resource types into an array in the order in which they should be deleted
    # Handles dependency-related issues - Ex: You must delete a Web App before you can delete an App Service Plan
	@(
        'Microsoft.Cache/Redis/'
        'Microsoft.ServiceBus/namespaces/topics'
        'Microsoft.ServiceBus/namespaces/'
        'Microsoft.Insights/alertrules/CPUHigh'
        'Microsoft.Insights/alertrules/ForbiddenRequests'
        'Microsoft.Insights/alertrules/ForbiddenRequests'
        'Microsoft.Insights/alertrules/LongHttpQueue'
        'Microsoft.Insights/alertrules/ServerErrors'
        'Microsoft.Insights/autoscalesettings'
        'Microsoft.Insights/components'
        'Microsoft.Sql/servers/databases'
        'Microsoft.Sql/servers'
        'Microsoft.Web/sites'
        'Microsoft.Web/serverFarms'
        'Microsoft.Devices/iotHubs/eventhubEndpoints/ConsumerGroups'
        'Microsoft.Devices/iotHubs/eventhubEndpoints'
        'Microsoft.Devices/iotHubs'

        '*' # this will remove everything else in the resource group regarding of resource type
     ) | % {
        $params = @{
            'ResourceGroupNameContains' = $ResourceGroupName
        }

        if ($_ -ne '*') {
            $params.Add('ResourceType', $_)
        }

        # Finds all the resources with Resource Types corresponding to the @params array
        $resources = Find-AzureRmResource @params

        # Removes all CIMS resources
        if (($ApplicationRemoval -eq "CIMS") -or ($ApplicationRemoval -eq "BOTH"))
        {
            $resources | Where-Object { $_.ResourceGroupName -eq $ResourceGroupName } | Where-Object { $_.ResourceName -match "CIMS" } | % { 
                Write-Host ('Processing {0}/{1}' -f $_.ResourceType, $_.ResourceName)
                $_ | Remove-AzureRmResource -Verbose -Force
            }
        }

        # Removes all G3MS resources
        if (($ApplicationRemoval -eq "G3MS") -or ($ApplicationRemoval -eq "BOTH"))
        {
            $resources | Where-Object { $_.ResourceGroupName -eq $ResourceGroupName } | Where-Object { $_.ResourceName -match "G3MS" } | % { 
                Write-Host ('Processing {0}/{1}' -f $_.ResourceType, $_.ResourceName)
                $_ | Remove-AzureRmResource -Verbose -Force
            }
        }

        # Removes all application-shared resources
        if ($ApplicationRemoval -eq "BOTH")
        {
            $resources | Where-Object { $_.ResourceGroupName -eq $ResourceGroupName } | Where-Object { $_.ResourceName -match "otiscloud" } | % { 
                Write-Host ('Processing {0}/{1}' -f $_.ResourceType, $_.ResourceName)
                $_ | Remove-AzureRmResource -Verbose -Force
            }
        }
    }
}

else
{
    "Resource Group " + $ResourceGroupName + " Not Found"
}