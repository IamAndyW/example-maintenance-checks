param (
    [Parameter(Mandatory = $true)]
    [hashtable] $externalConfiguration
)

BeforeDiscovery {
    $internalConfigurationFilename = $externalConfiguration.checkConfigurationFilename
    $checkName = $externalConfiguration.checkName

    # loading check configuration
    if (-not (Test-Path -Path $internalConfigurationFilename)) {
        throw ("Missing configuration file: {0}" -f $internalConfigurationFilename)
    }

    $internalConfiguration = (Get-Content -Path $internalConfigurationFilename |
        ConvertFrom-Json -Depth 99).$checkName
    
    if ($null -eq $internalConfiguration) {
        throw ("Cannot find configuration: {0} in file: {1}" -f $checkName, $internalConfigurationFilename)
    }

    # installing dependencies
    . ../../powershell/Install-PowerShellModules.ps1 -moduleNames ("PowerShellForGitHub")
    
    # GitHub authentication
    $secureString = ($externalConfiguration.githubToken | ConvertTo-SecureString -AsPlainText -Force)
    $credential = New-Object System.Management.Automation.PSCredential "username is ignored", $secureString
    Set-GitHubAuthentication -Credential $credential -SessionOnly

    # building the discovery object
    $repositories = [System.Collections.ArrayList]@()

    foreach ($repositoryName in $internalConfiguration.repositories) {
        $pullRequests = Get-GitHubPullRequest -OwnerName $internalConfiguration.owner -RepositoryName $repositoryName |
            Where-Object {$_.state -eq 'open' -and $_.user.login -eq 'dependabot[bot]'} |
                Select-Object -Property title, created_at

        $repositoryObject = [ordered] @{
            repositoryName = $repositoryName
            dependabotPRStaleInDays = $internalConfiguration.dependabotPRStaleInDays
            dependabotPRMaxCount = $internalConfiguration.dependabotPRMaxCount
            pullRequests = $pullRequests
        }

        $repository = New-Object PSObject -property $repositoryObject
        $repositories.Add($repository)
    }

    $discovery = @{
        runbook = $internalConfiguration.runbook
        owner = $internalConfiguration.owner
        repositories = $repositories
    }

    $dateThreshold = $externalConfiguration.checkDateTime.AddDays(-$internalConfiguration.dependabotPRStaleInDays)
}

Describe "$($externalConfiguration.checkDisplayName) / <_.owner>" -ForEach $discovery {

    Context "Repository: '<_.repositoryName>'" -ForEach $_.repositories {

        BeforeAll {
            Write-Host "`n"
            $dateThreshold = $externalConfiguration.checkDateTime.AddDays(-$_.dependabotPRStaleInDays)
        }

        It "Dependabot PR '<_.title>' creation date should not be older than $($dateThreshold.ToString($externalConfiguration.checkDateFormat))" -ForEach $_.pullRequests {
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
