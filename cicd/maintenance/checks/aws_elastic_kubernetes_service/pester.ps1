param (
    [Parameter(Mandatory = $true)]
    [hashtable] $externalConfiguration
)

BeforeDiscovery {
    Push-Location -Path $PSScriptRoot
    
    $internalConfigurationFilename = $externalConfiguration.checkConfigurationFilename
    $stageName = $externalConfiguration.stageName
    $checkName = $externalConfiguration.checkName

    # loading check configuration
    if (-not (Test-Path -Path $internalConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $internalConfigurationFilename)
    }

    $internalConfiguration = ((Get-Content -Path $internalConfigurationFilename |
        ConvertFrom-Json -Depth 99).stages |
            Where-Object {$_.name-eq $stageName}).$checkName
    
    if ($null -eq $internalConfiguration) {
        throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $stageName, $internalConfigurationFilename)
    }

    # building the discovery object
    $discovery = [System.Collections.ArrayList]@()

    foreach ($resource in $internalConfiguration.clusters) {
        $discoveryObject = [ordered] @{
            versionThreshold = $internalConfiguration.versionThreshold
            resourceName = $resource.resourceName
            resourceRegion = $resource.resourceRegion
        }
        $context = New-Object PSObject -property $discoveryObject
        $discovery.Add($context)
    }
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
        $resourceName = $_.resourceName
        $resourceRegion = $_.resourceRegion

        try {
            $resource = Get-EKSCluster -Name $resourceName -Region $resourceRegion
        }
        catch {
            throw ("Cannot find resource: '{0}' in region: '{1}'" -f $resourceName, $resourceRegion)
        }      
    }

    Context "Status: '<_.resourceName>/<_.resourceRegion>'" {

        It "Should have a Status of ACTIVE" {
            $resource.Status | Should -Be "ACTIVE"
        }
        
    }

    Context "Version: '<_.resourceName>/<_.resourceRegion>'" {

        BeforeAll {
            $currentVersion = $resource.Version
            $versionThreshold = $_.versionThreshold

            $targetVersions = (Get-EKSAddonVersion -AddonName 'vpc-cni' -Region $resourceRegion).AddonVersions.Compatibilities.ClusterVersion |
                Sort-Object {$_ -as [version]} -Unique -Descending |
                    Select-Object -First $versionThreshold
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

            Clear-Variable -Name "currentVersion"
            Clear-Variable -Name "versionThreshold"
            Clear-Variable -Name "targetVersions"
        }
    }

    AfterAll {
        Clear-Variable -Name "resourceName"
        Clear-Variable -Name "resourceRegion"
        Clear-Variable -Name "resource"
    }
}

AfterAll {
    Clear-AWSCredential
}
