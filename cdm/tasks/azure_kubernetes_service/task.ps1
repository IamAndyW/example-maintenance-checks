<#
    This is the CDM task
#>

Push-Location -Path $PSScriptRoot

# installing dependencies
. ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("powershell-yaml", "Az.Aks")

# Azure authentication
. ../../../powershell/Connect-Azure.ps1 `
    -tenantId $env:ARM_TENANT_ID `
    -subscriptionId $env:ARM_SUBSCRIPTION_ID `
    -clientId $env:ARM_CLIENT_ID `
    -clientSecret $env:ARM_CLIENT_SECRET

# task configuration
$taskConfigurationFilename = $pipelineConfiguration.taskConfigurationFilename
$taskName = $pipelineConfiguration.taskName
$stageName = $pipelineConfiguration.stageName

# loading task configuration
if (-not (Test-Path -Path $taskConfigurationFilename)) {
    throw ("Missing configuration file: {0}" -f $taskConfigurationFilename)
}

$taskConfiguration = (Get-Content -Path $taskConfigurationFilename | ConvertFrom-Yaml).$taskName

if ($null -eq $taskConfiguration) {
    throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $taskName, $taskConfigurationFilename)
}


# running task against resource
$clusters = ($taskConfiguration.stages | Where-Object {$_.name -eq $stageName}).clusters

foreach ($cluster in $clusters) {

    $resourceGroupName = $cluster.resourceGroupName
    $resourceName = $cluster.resourceName

    try {
        $resource = Get-AzAksCluster -ResourceGroupName $resourceGroupName -Name $resourceName
    }
    catch {
        throw ("Cannot find resource: '{0}' in resource group: '{1}'" -f $resourceName, $resourceGroupName)
    }

    if ($resource.tags.keys -notcontains 'CDM_configuration') {
        Write-Warning ("Resource: {0} in Resource Group: {1} is missing the tag: {2}`n" -f $resourceGroupName, $resourceName, "")
        Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping CDM task"
    }
}





Pop-Location
