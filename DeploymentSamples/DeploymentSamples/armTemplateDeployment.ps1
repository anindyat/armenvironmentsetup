$aadClientId = '77d30e9a-a1d5-42e6-a4b1-d8009b1fbbd7'
$aadClientSecret = 'AKKbp0VTYj1yDhwURVGLAB/FeYKS6aNA7lMOyWbCQEw='
$aadTenantId = '3df212f7-caab-434b-bf95-980c5f161c43'
$deploymentBaseUri = "https://management.azure.com/subscriptions/e41d3122-b0d8-48dc-a212-0337139671cc/resourceGroups/TestResourceGroup/providers/Microsoft.Resources/deployments/"
$deploymentTemplate = get-content 'C:\Users\ryan.j.lilla\Desktop\Otis IoT\AutomationScripts\deploymentTemplate.json'

$armTokenResourceEndpoint = 'https://management.azure.com/'
$authUri = 'https://login.microsoftonline.com/' + $aadTenantId + '/oauth2/token'

$tokenHeaders = @{ 'Content-Type' =  "application/x-www-form-urlencoded" }
$tokenBody = "grant_type=client_credentials&resource=$($armTokenResourceEndpoint)&client_id=$($aadClientId)&client_secret=$($aadClientSecret)"
try { $trapTokenResponse = Invoke-WebRequest -Method POST -Uri $authUri -headers $tokenHeaders -body $tokenBody }
catch { throw $_ }
$token = ($trapTokenResponse | ConvertFrom-Json).access_token

$armHeaders = @{ 'Authorization' = "Bearer $token"; 'Content-Type' = "Application/json" }
$deploymentName = ((get-date).ToUniversalTime()).ToString('yyyyMMddHHmmss')

$validateUri = "$($deploymentBaseUri)$($deploymentName)/validate?api-version=2017-05-10"
try { $trapValidateResponse = Invoke-RestMethod -Method POST -Headers $armHeaders -Uri $validateUri -Body $deploymentTemplate }
catch { throw $_ }

$deploymentUri = "$($deploymentBaseUri)$($deploymentName)?api-version=2017-05-10"
try { $trapDeploymentResponse = Invoke-RestMethod -Method PUT -Headers $armHeaders -Uri $deploymentUri -Body $deploymentTemplate }
catch { throw $_ }

$deploymentStatus = $null
while ( !$deploymentStatus ) {
    start-sleep -Seconds 5
    $trapDeploymentStatusResponse = Invoke-RestMethod -Method GET -Headers $armHeaders -Uri $deploymentUri
    if ( $trapDeploymentStatusResponse.properties.provisioningState -eq "Succeeded" ) { $deploymentStatus = "Succeeded" }
    elseif ( $trapDeploymentStatusResponse.properties.provisioningState -eq "Failed" ) { $deploymentStatus = "Failed"; throw $trapDeploymentStatusResponse.properties.error.details.message }
}