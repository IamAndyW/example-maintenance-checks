param (
    [Parameter(Mandatory = $true)]
    [hashtable] $runtimeConfiguration
)

BeforeDiscovery {
    Push-Location -Path $PSScriptRoot
    
    $checkConfigurationFilename = $runtimeConfiguration.checkConfigurationFilename
    $stageName = $runtimeConfiguration.stageName
    $checkName = $runtimeConfiguration.checkName

    # loading check configuration
    if (-not (Test-Path -Path $checkConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $checkConfigurationFilename)
    }

    $script:checkConfiguration = ((Get-Content -Path $checkConfigurationFilename |
        ConvertFrom-Json -Depth 99).stages |
            Where-Object {$_.name-eq $stageName}).$checkName
    
    if ($null -eq $checkConfiguration) {
        throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $stageName, $checkConfigurationFilename)
    }

    # building the discovery object
    $script:discovery = [System.Collections.ArrayList]@()

    foreach ($cluster in $checkConfiguration.clusters) {
        $discoveryObject = [ordered] @{
            aksVersionThreshold = $checkConfiguration.aksVersionThreshold
            resourceGroupName = $cluster.resourceGroupName
            resourceName = $cluster.resourceName
        }
        $context = New-Object PSObject -property $discoveryObject
        $discovery.Add($context)
    }
} 

Describe $((Get-Culture).TextInfo.ToTitleCase($checkName.Replace('_', ' '))) {
    BeforeAll {
        # installing dependencies
        . ../../powershell/Connect-Azure.ps1
        . ../../powershell/Install-PowerShellModules.ps1 -modules ("Az.Aks")
    }

    Context "Cluster: '<_.resourceGroupName>/<_.resourceName>'" -ForEach $discovery {

        BeforeAll {
            $resourceGroupName = $_.resourceGroupName
            $resourceName = $_.resourceName

            try {
                $azureResource = Get-AzAksCluster -ResourceGroupName $resourceGroupName -Name $resourceName
            }
            catch {
                throw ("Cannot find resource: '{0}' in resource group" -f $resourceName, $resourceGroupName)
            }

            $currentVersion = $azureResource.KubernetesVersion
            $aksVersionThreshold = $_.aksVersionThreshold
            
            $targetVersions = (Get-AzAksVersion -Location $azureResource.Location |
            Where-Object {$_.IsPreview -ne $true} | Sort-Object { $_.OrchestratorVersion -as [version] } -Descending).OrchestratorVersion |
                Select-Object -First $aksVersionThreshold

            Write-Host ""
        }

        It "Should have 'ProvisioningState' of 'Succeeded'" {
            $azureResource.ProvisioningState | Should -Be "Succeeded"
        }
        
        It "The current version should be within target versions" {       

            $targetVersions -contains $currentVersion | Should -Be $true
        }

        AfterAll {
            Write-Host ("`nCurrent version {0}" -f $currentVersion)

            Write-Host("`nTarget versions (N-{0}) for {1}" -f $aksVersionThreshold, $azureResource.Location)
            foreach ($version in $targetVersions) {
                Write-Host $version
            }
            
            Write-Host ""

            Clear-Variable -Name "resourceGroupName"
            Clear-Variable -Name "resourceName"
            Clear-Variable -Name "azureResource"
            Clear-Variable -Name "currentVersion"
            Clear-Variable -Name "aksVersionThreshold"
            Clear-Variable -Name "targetVersions"
        }
    }
}
