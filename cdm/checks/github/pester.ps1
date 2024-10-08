param (
    [Parameter(Mandatory = $true)]
    [hashtable] $pipelineConfiguration
)

BeforeDiscovery {
    # installing dependencies
    . ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("PowerShellForGitHub", "powershell-yaml")

    $checkConfigurationFilename = $pipelineConfiguration.checkConfigurationFilename

    # loading check configuration
    if (-not (Test-Path -Path $checkConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $checkConfigurationFilename)
    }

    $checkConfiguration = Get-Content -Path $checkConfigurationFilename | ConvertFrom-Yaml
    
    # GitHub authentication
    $secureString = ($pipelineConfiguration.githubToken | ConvertTo-SecureString -AsPlainText -Force)
    $credential = New-Object System.Management.Automation.PSCredential "username is ignored", $secureString
    Set-GitHubAuthentication -Credential $credential -SessionOnly

    # building the discovery objects
    $repositories = [System.Collections.ArrayList]@()

    foreach ($repositoryName in $checkConfiguration.repositories) {
        $pullRequests = Get-GitHubPullRequest -OwnerName $checkConfiguration.owner -RepositoryName $repositoryName |
            Where-Object {$_.state -eq 'open' -and $_.user.login -eq 'dependabot[bot]'} |
                Select-Object -Property title, created_at

        $repositoryObject = [ordered] @{
            repositoryName = $repositoryName
            dependabotPRStaleInDays = $checkConfiguration.dependabotPRStaleInDays
            dependabotPRMaxCount = $checkConfiguration.dependabotPRMaxCount
            pullRequests = $pullRequests
        }

        $repository = New-Object PSObject -property $repositoryObject
        $repositories.Add($repository)
    }

    $discovery = @{
        runbook = $checkConfiguration.runbook
        owner = $checkConfiguration.owner
        repositories = $repositories
    }

    $dateThreshold = $pipelineConfiguration.checkDateTime.AddDays(-$checkConfiguration.dependabotPRStaleInDays)
}

Describe "$($pipelineConfiguration.checkDisplayName) / <_.owner>" -ForEach $discovery {

    Context "Repository: '<_.repositoryName>'" -ForEach $_.repositories {

        BeforeAll {
            Write-Host "`n"
            $dateThreshold = $pipelineConfiguration.checkDateTime.AddDays(-$_.dependabotPRStaleInDays)
        }

        It "Dependabot PR '<_.title>' creation date should not be older than $($dateThreshold.ToString($pipelineConfiguration.checkDateFormat))" -ForEach $_.pullRequests {
            $_.created_at | Should -BeGreaterThan $dateThreshold
        }

        It "The number of Dependabot PRs should be less than or equal to <_.dependabotPRMaxCount>" {
            $_.pullRequests.count | Should -BeLessOrEqual $_.dependabotPRMaxCount
        }

        AfterAll {
            Write-Host ("`nGitHub Pull Request link: http://github.com/{0}/{1}/pulls" -f $_.owner, $_.repositoryName)
            Clear-Variable -Name "dateThreshold"
        }
    }

    AfterAll {
        Write-Host ("`nRunbook: {0}`n" -f $_.runbook)
    }
}

AfterAll {
    Clear-GitHubAuthentication
}
