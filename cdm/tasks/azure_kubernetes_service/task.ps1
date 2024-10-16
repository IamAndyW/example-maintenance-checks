<#
    This is the CDM task
#>

Push-Location -Path $PSScriptRoot

# installing dependencies
# to avoid a potential clash with the YamlDotNet libary always load the module 'powershell-yaml' last
. ../../../powershell/functions/Install-PowerShellModules.ps1
Install-PowerShellModules -moduleNames ("Az.Aks", "powershell-yaml")

# task configuration
$script:configurationFilename = $parentConfiguration.configurationFilename
$script:stageName = $parentConfiguration.stageName

# loading task configuration
if (-not (Test-Path -Path $configurationFilename)) {
    throw ("Missing configuration file '{0}/{1}'" -f $parentConfiguration.taskDirectory, $configurationFilename)
}

$script:taskConfiguration = Get-Content -Path $configurationFilename | ConvertFrom-Yaml

# running task against resource
$script:clusters = ($taskConfiguration.stages | Where-Object {$_.name -eq $stageName}).clusters

if ($parentConfiguration.action -notin $taskConfiguration.allowedActions) {
    throw ("Action '{0}' not valid for the task '{1}'. Check task configuration file for a list of allowed actions '{2}/{3}'" -f $parentConfiguration.action, $parentConfiguration.displayName, $parentConfiguration.taskDirectory, $configurationFilename)
}

# configuration
$parentConfiguration.Add('armTenantId', $env:ARM_TENANT_ID)
$parentConfiguration.Add('armSubscriptionId', $env:ARM_SUBSCRIPTION_ID)
$parentConfiguration.Add('armClientId', $env:ARM_CLIENT_ID)
$parentConfiguration.Add('armClientSecret', $env:ARM_CLIENT_SECRET)

# Azure authentication
. ../../../powershell/functions/Connect-Azure.ps1
Connect-Azure `
    -tenantId $parentConfiguration.armTenantId `
    -subscriptionId $parentConfiguration.armSubscriptionId `
    -clientId $parentConfiguration.armClientId `
    -clientSecret $parentConfiguration.armClientSecret

# iterating over the resources
foreach ($cluster in $clusters) {
    $script:resourceGroupName = $cluster.resourceGroupName
    $script:resourceName = $cluster.resourceName

    Write-Information -MessageData ("`nProcessing Resource '{0}' in Resource Group '{1}'" -f $resourceName, $resourceGroupName)

    $script:resource = Get-AzAksCluster -ResourceGroupName $resourceGroupName -Name $resourceName

    if ($resource.tags.keys -contains $parentConfiguration.configurationResourceTagName) {

        $script:tagConfiguration = $resource.tags.($parentConfiguration.configurationResourceTagName).Split(',')
    
        foreach ($script:item in $tagConfiguration) {
            $script:keyValue = $item.Split('=')
            $taskConfiguration.Add($keyValue[0], $keyValue[1])
        }

        if ($taskConfiguration.enabled -eq "true") {      
            Write-Information -MessageData ("Action '{0}'`n" -f $parentConfiguration.action)

            switch ($parentConfiguration.action) {
                "StartAKS" {
                    if (($resource.ProvisioningState -eq "Succeeded") -and ($resource.PowerState.Code -eq "Stopped")) {
                        Start-AzAksCluster -ResourceGroupName $resourceGroupName -Name $resourceName
                    } else {
                        Write-Warning ("Resource is not in a valid state to perform the action '{0}'. ProvisioningState '{1}' and PowerState '{2}'" -f $parentConfiguration.action, $resource.ProvisioningState, $resource.PowerState.Code)
                        Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping CDM task"
                    }
                }
                "StopAKS" {
                    if (($resource.ProvisioningState -eq "Succeeded") -and ($resource.PowerState.Code -eq "Running")) {
                        Stop-AzAksCluster -ResourceGroupName $resourceGroupName -Name $resourceName
                    } else {
                        Write-Warning ("Resource is not in a valid state to perform the action '{0}'. ProvisioningState '{1}' and PowerState '{2}'" -f $parentConfiguration.action, $resource.ProvisioningState, $resource.PowerState.Code)
                        Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping CDM task"
                    }
                }
            }   

        } else {
            Write-Warning ("CDM Tasks are not enabled on this resource. Check the resource tag '{0}'" -f $parentConfiguration.configurationResourceTagName)
            Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping CDM task"
        }
    } else {
        Write-Warning ("Resource is missing the tag '{0}'" -f $parentConfiguration.configurationResourceTagName)
        Write-Host "##vso[task.complete result=SucceededWithIssues]Skipping CDM task"
    }
}

Pop-Location
