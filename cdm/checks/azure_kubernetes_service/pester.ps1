param (
    [Parameter(Mandatory = $true)]
    [hashtable] $pipelineConfiguration
)

BeforeDiscovery {
    # installing dependencies
    . ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("Az.Aks","powershell-yaml")

    $checkConfigurationFilename = $pipelineConfiguration.checkConfigurationFilename
    $stageName = $pipelineConfiguration.stageName

    # loading check configuration
    if (-not (Test-Path -Path $checkConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $checkConfigurationFilename)
    }

    $checkConfiguration = Get-Content -Path $checkConfigurationFilename | ConvertFrom-Yaml

    # building the discovery objects
    $discovery = $checkConfiguration
    $clusters = $discovery.stages | Where-Object {$_.name -eq $stageName} | Select-Object -ExpandProperty clusters
}

BeforeAll {
    # Azure authentication
    . ../../../powershell/Connect-Azure.ps1 `
        -tenantId $pipelineConfiguration.armTenantId `
        -subscriptionId $pipelineConfiguration.armSubscriptionId `
        -clientId $pipelineConfiguration.armClientId `
        -clientSecret $pipelineConfiguration.armClientSecret
}

Describe $pipelineConfiguration.checkDisplayName -ForEach $discovery {

    BeforeAll {        
        $versionThreshold = $_.versionThreshold    
    }

    Context "Cluster: <_.resourceGroupName>/<_.resourceName>" -ForEach $clusters {
        BeforeAll {
            $resourceGroupName = $_.resourceGroupName
            $resourceName = $_.resourceName
    
            try {
                $resource = Get-AzAksCluster -ResourceGroupName $resourceGroupName -Name $resourceName
            }
            catch {
                throw ("Cannot find resource: '{0}' in resource group: '{1}'" -f $resourceName, $resourceGroupName)
            }
    
            $currentVersion = $resource.KubernetesVersion
            
            $targetVersions = (Get-AzAksVersion -Location $resource.Location |
            Where-Object {$_.IsPreview -ne $true} | Sort-Object { $_.OrchestratorVersion -as [version] } -Descending).OrchestratorVersion |
                Select-Object -First $versionThreshold

        }

        It "Should have Provisioning State of 'Succeeded'" {
            $resource.ProvisioningState | Should -Be "Succeeded"
        }

        It "The current version should be within target versions" {       
            $targetVersions -contains $currentVersion | Should -Be $true
        }

        AfterAll {
            Write-Host ("`nCurrent version {0}" -f $currentVersion)

            Write-Host("`nTarget versions (n-{0}) for {1}" -f $versionThreshold, $resourceRegion)
            foreach ($version in $targetVersions) {
                Write-Host $version
            }

            Write-Host ""
            
            Clear-Variable -Name "resourceGroupName"
            Clear-Variable -Name "resourceName"
            Clear-Variable -Name "resource"
            Clear-Variable -Name "currentVersion"
            Clear-Variable -Name "targetVersions"
        }
    }

    AfterAll {
        Write-Host ("`nRunbook: {0}`n" -f $_.runbook)
        
        Clear-Variable -Name "versionThreshold"
    }
}

AfterAll {
    Clear-AzContext -Scope CurrentUser -Force
}
