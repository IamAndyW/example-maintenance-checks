param (
    [Parameter(Mandatory = $true)]
    [hashtable] $externalConfiguration
)

BeforeDiscovery {
    $internalConfigurationFilename = $externalConfiguration.checkConfigurationFilename
    $checkName = $externalConfiguration.checkName
    $stageName = $externalConfiguration.stageName

    # loading check configuration
    if (-not (Test-Path -Path $internalConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $internalConfigurationFilename)
    }

    $internalConfiguration = (Get-Content -Path $internalConfigurationFilename |
        ConvertFrom-Json -Depth 99).$checkName
    
    if ($null -eq $internalConfiguration) {
        throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $checkName, $internalConfigurationFilename)
    }

    # building the discovery objects
    $discovery = $internalConfiguration
    $clusters = ($discovery.stages | Where-Object {$_.name -eq $stageName}).clusters
}

BeforeAll {
    # installing dependencies
    . ../../powershell/Install-PowerShellModules.ps1 -moduleNames ("AWS.Tools.Installer")
    Install-AWSToolsModule AWS.Tools.Common, AWS.Tools.EKS -Force

    # AWS authentication
    Set-AWSCredential -AccessKey $externalConfiguration.awsAccessKeyId -SecretKey $externalConfiguration.awsSecretAccessKey 
}

Describe $externalConfiguration.checkDisplayName -ForEach $discovery {

    BeforeAll {
        $versionThreshold = $_.versionThreshold
    }

    Context "Cluster: <_.resourceRegion>/<_.resourceName>" -ForEach $clusters {
        BeforeAll {
            $resourceName = $_.resourceName
            $resourceRegion = $_.resourceRegion
    
            try {
                $resource = Get-EKSCluster -Name $resourceName -Region $resourceRegion
            }
            catch {
                throw ("Cannot find resource: '{0}' in region: '{1}'" -f $resourceName, $resourceRegion)
            }

            $currentVersion = $resource.Version
            $targetVersions = (Get-EKSAddonVersion -AddonName 'vpc-cni' -Region $resourceRegion).AddonVersions.Compatibilities.ClusterVersion |
                Sort-Object {$_ -as [version]} -Unique -Descending |
                    Select-Object -First $versionThreshold 
        }

        It "Should have a Status of ACTIVE" {
            $resource.Status | Should -Be "ACTIVE"
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

            Clear-Variable -Name "resourceName"
            Clear-Variable -Name "resourceRegion"
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
    Clear-AWSCredential
}
