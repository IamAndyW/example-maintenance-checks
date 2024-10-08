param (
    [Parameter(Mandatory = $true)]
    [hashtable] $pipelineConfiguration
)

BeforeDiscovery {
    # installing dependencies
    . ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("AWS.Tools.Installer")
    Install-AWSToolsModule AWS.Tools.Common, AWS.Tools.EKS -Force
    Import-Module -Name "AWS.Tools.Common" -Force
    Import-Module -Name "AWS.Tools.EKS" -Force
    . ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("powershell-yaml")

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
    # AWS authentication
    Set-AWSCredential -AccessKey $pipelineConfiguration.awsAccessKeyId -SecretKey $pipelineConfiguration.awsSecretAccessKey 
}

Describe $pipelineConfiguration.checkDisplayName -ForEach $discovery {

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
