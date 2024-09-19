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

    $checkConfiguration = ((Get-Content -Path $checkConfigurationFilename |
        ConvertFrom-Json -Depth 99).stages |
            Where-Object {$_.name-eq $stageName}).$checkName
    
    if ($null -eq $checkConfiguration) {
        throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $stageName, $checkConfigurationFilename)
    }

    # building the discovery object
    $discovery = [System.Collections.ArrayList]@()

    foreach ($resource in $checkConfiguration.clusters) {
        $discoveryObject = [ordered] @{
            aksVersionThreshold = $checkConfiguration.aksVersionThreshold
            resourceGroupName = $resource.resourceGroupName
            resourceName = $resource.resourceName
        }
        $context = New-Object PSObject -property $discoveryObject
        $discovery.Add($context)
    }
}


Describe $((Get-Culture).TextInfo.ToTitleCase($checkName.Replace('_', ' '))) {
    
    BeforeAll {
        Write-Host "`n"

        # Azure authentication
        . ../../powershell/Connect-Azure.ps1
        
        # installing dependencies
        . ../../powershell/Install-PowerShellModules.ps1 -modules ("Az.Aks")
    }

    Context "Cluster: '<_.resourceGroupName>/<_.resourceName>'" -ForEach $discovery {

        BeforeAll {
            Write-Host "`n"

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

            Write-Host "`n"
        }

        # // START of tests //
        It "Should have 'ProvisioningState' of 'Succeeded'" {
            $azureResource.ProvisioningState | Should -Be "Succeeded"
        }        
        
        It "The current version should be within target versions" {       
            $targetVersions -contains $currentVersion | Should -Be $true
        }
        # // END of tests //

        
        AfterAll {
            Write-Host ("`nCurrent version {0}" -f $currentVersion)

            Write-Host("`nTarget versions (N-{0}) for {1}`n" -f $aksVersionThreshold, $azureResource.Location)
            foreach ($version in $targetVersions) {
                Write-Host $version
            }

            Clear-Variable -Name "resourceGroupName"
            Clear-Variable -Name "resourceName"
            Clear-Variable -Name "azureResource"
            Clear-Variable -Name "currentVersion"
            Clear-Variable -Name "aksVersionThreshold"
            Clear-Variable -Name "targetVersions"
        }
    }
}
