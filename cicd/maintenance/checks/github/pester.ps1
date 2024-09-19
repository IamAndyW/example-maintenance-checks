param (
    [Parameter(Mandatory = $true)]
    [hashtable] $runtimeConfiguration
)

BeforeDiscovery {
    Push-Location -Path $PSScriptRoot
    
    $checkConfigurationFilename = $runtimeConfiguration.checkConfigurationFilename
    $checkName = $runtimeConfiguration.checkName

    # loading check configuration
    if (-not (Test-Path -Path $checkConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $checkConfigurationFilename)
    }

    $checkConfiguration = (Get-Content -Path $checkConfigurationFilename |
        ConvertFrom-Json -Depth 99).$checkName
    
    if ($null -eq $checkConfiguration) {
        throw ("Cannot find configuration: '{0}' in file: '{1}'" -f $stageName, $checkConfigurationFilename)
    }

    # installing dependencies
    . ../../powershell/Install-PowerShellModules.ps1 -modules ("PowerShellForGitHub")
    
    # GitHub authentication
    $secureString = ($runtimeConfiguration.githubToken | ConvertTo-SecureString -AsPlainText -Force)
    $credential = New-Object System.Management.Automation.PSCredential "username is ignored", $secureString
    Set-GitHubAuthentication -Credential $credential -SessionOnly

    # building the discovery object
    $discovery = [System.Collections.ArrayList]@()

    foreach ($repository in $checkConfiguration.repositories) {
        $pullRequests = Get-GitHubPullRequest -OwnerName $checkConfiguration.owner -RepositoryName $repository |
            Where-Object {$_.state -eq 'open' -and $_.user.login -eq 'dependabot[bot]'} |
                Select-Object -Property title, created_at
        
        $discoveryObject = [ordered] @{
            owner = $checkConfiguration.owner
            dependabotPRStaleInDays = $checkConfiguration.dependabotPRStaleInDays
            dependabotPRMaxCount = $checkConfiguration.dependabotPRMaxCount
            repositoryName = $repository           
            pullRequests = $pullRequests
        }
        $context = New-Object PSObject -property $discoveryObject
        $discovery.Add($context)

        $dependabotPRStaleInDays = $checkConfiguration.dependabotPRStaleInDays
        $dependabotPRMaxCount = $checkConfiguration.dependabotPRMaxCount
    }
}

Describe $((Get-Culture).TextInfo.ToTitleCase($checkName.Replace('_', ' '))) {

    Context "Repository: '<_.repositoryName>'" -ForEach $discovery {

        BeforeAll {
            Write-Host "`n"

            $dateThreshold = (Get-Date).AddDays(-$_.dependabotPRStaleInDays)
            $dependabotPRMaxCount = $_.dependabotPRMaxCount
        }

        # // START of tests //
        It "Dependabot PR '<_.title>' creation date should not be older than $dependabotPRStaleInDays days" -ForEach $_.pullRequests {
            $_.created_at -lt $dateThreshold | Should -Be $false
        }

        It "The number of Dependabot PRs should be less than or equal to $dependabotPRMaxCount" {
            $_.pullRequests.count | Should -BeLessOrEqual $dependabotPRMaxCount
        }
        # // END of tests //

        AfterAll {
            Write-Host ("`nGitHub Pull Request link: http://github.com/{0}/{1}/pulls`n" -f $_.owner, $_.repositoryName)
            Clear-Variable -Name "dateThreshold"
            Clear-Variable -Name "dependabotPRMaxCount"
        }
    }
}

AfterAll {
    Clear-GitHubAuthentication
}
