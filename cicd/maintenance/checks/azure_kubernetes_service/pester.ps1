param (
    [Parameter(Mandatory = $true)]
    [hashtable] $externalConfiguration
)

BeforeDiscovery {
    $internalConfigurationFilename = $externalConfiguration.checkConfigurationFilename
    $stageName = $externalConfiguration.stageName

    # loading check configuration
    if (-not (Test-Path -Path $internalConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $internalConfigurationFilename)
    }

    $internalConfiguration = (Get-Content -Path $internalConfigurationFilename |
        ConvertFrom-Json -Depth 99).stages |
            Where-Object {$_.name-eq $stageName}
    
    if ($null -eq $internalConfiguration) {
        throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $stageName, $internalConfigurationFilename)
    }

    # building the discovery object
    $discovery = $internalConfiguration
}

BeforeAll {
    # Azure authentication
    . ../../powershell/Connect-Azure.ps1 `
        -tenantId $externalConfiguration.armTenantId `
        -subscriptionId $externalConfiguration.armSubscriptionId `
        -clientId $externalConfiguration.armClientId `
        -clientSecret $externalConfiguration.armClientSecret

    # installing dependencies
    . ../../powershell/Install-PowerShellModules.ps1 -moduleNames ("Az.Aks")
}

Describe $externalConfiguration.checkDisplayName -ForEach $discovery.$($externalConfiguration.checkName) {

    BeforeAll {
        $versionThreshold = $_.versionThreshold    
    }

    Context "Gateway: <_.resourceGroupName>/<_.resourceName>" -ForEach $_.clusters {
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
        Clear-Variable -Name "versionThreshold"
    }
}

AfterAll {
    Clear-AzContext -Scope CurrentUser -Force
}
