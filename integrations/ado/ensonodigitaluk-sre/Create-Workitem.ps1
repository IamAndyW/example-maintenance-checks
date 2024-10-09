
<#
    This script is responsible for creating and linking the ADO work items for the Ensono Digital SRE ADO project.
#>

Push-Location -Path $PSScriptRoot

# # dot-sourcing functions
. ../../../powershell/functions/Find-ADOWorkItemsByQuery.ps1
. ../../../powershell/functions/New-ADOWorkItem.ps1

# // START check for existing Product Backlog Item //
$script:wiTitle = ("{0}: {1} {2} FAILED" -f $env:SYSTEM_DEFINITIONNAME, $env:SYSTEM_STAGEDISPLAYNAME, $env:SYSTEM_PHASEDISPLAYNAME)

$script:wiPBIQuery = (
    "Select [System.Id],
    [System.Title],
    [System.WorkItemType],
    [System.State]
    From WorkItems
    WHERE [System.WorkItemType] = 'Product Backlog Item'
    AND
    [System.Title] = '{0}'
    AND [State] <> 'Closed'
    AND [State] <> 'Removed'" -f $wiTitle
)

$script:wiPBIs = Find-ADOWorkItemsByQuery -baseURL $adoConfiguration.baseUrl -accessToken $adoConfiguration.accessToken -wiQuery $wiPBIQuery
# // END check for existing Product Backlog Item //

if ($wiPBIs.workItems.Count -eq 0) {
    Write-Information -MessageData ("Creating a new work item with name '{0}'" -f $wiTitle)

    # // START discover work item parent //
    . ../../../powershell/Install-PowerShellModules.ps1 -moduleNames ("powershell-yaml")

    $script:parentMappings = (Get-Content -Path $adoConfiguration.configurationFilename |
        ConvertFrom-Yaml).($adoConfiguration.action).parentMappings |
            Where-Object {$_.clientName -eq $adoConfiguration.clientName}

    if ($null -eq $parentMappings) {
        throw ("Missing the '{0}' configuration for the action '{1}' and client '{2}'" -f "parentMappings", $adoConfiguration.action, $adoConfiguration.clientName)
    }

    $script:wiParentQuery = (
        "SELECT
            [System.Id],
            [System.WorkItemType],
            [System.Title],
            [System.Links.LinkType]
            FROM
            WorkItemLinks
            WHERE
            (
                [Source].[System.WorkItemType] = 'Feature'
                AND [Source].[System.Title] = '{0}'
                AND [System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Reverse'
                AND [Target].[System.Title] = '{1}'
            )" -f $parentMappings.($adoConfiguration.checkName), $adoConfiguration.clientName
    )

    $script:wiParent = (Find-ADOWorkItemsByQuery -baseURL $adoConfiguration.baseUrl -accessToken $adoConfiguration.accessToken -wiQuery $wiParentQuery).workItemRelations.source
    # // STOP discover work item parent //

    # // START creating new PBI //
    $script:wiDescription = (
        "<a href='{0}{1}/_build/results?buildId={2}&view=logs&s={3}&j={4}'>Build: {5}</a>" -f $env:SYSTEM_COLLECTIONURI, $env:SYSTEM_TEAMPROJECT, $env:BUILD_BUILDID, $env:SYSTEM_STAGEID, $env:SYSTEM_JOBID, $env:BUILD_BUILDNUMBER
    )

    $payload = @(
        @{
            op = "add"
            path = "/fields/System.Title"
            from = $null
            value = ("{0}" -f $wiTitle)
        }
        @{
            op = "add"
            path = "/fields/System.Description"
            from = $null
            value = ("{0}" -f $wiDescription)
        }
        @{
            op = "add"
            path = "/fields/Custom.ValuetoBusiness"
            from = $null
            value = ("{0}" -f "4. 5 = Some benefit to one team")
        }
        @{
            op = "add"
            path = "/fields/Custom.RiskReduction"
            from = $null
            value = ("{0}" -f "2. 20 = Major risk to security/vulnerability")
        }
        @{
            op = "add"
            path = "/fields/Custom.JobSize"
            from = $null
            value = ("{0}" -f "5. 8 = 3 Days")
        }
        @{
            op = "add"
            path = "/fields/Custom.TimeCritical"
            from = $null
            value = ("{0}" -f "5. 8 = 1 Month")
        }
        @{
            op = "add"
            path = "/relations/-"
            from = $null
            value = @{
                rel = "System.LinkTypes.Hierarchy-Reverse"
                url = ("{0}" -f $wiParent.url)
            }
        }
    )

    $script:newWI = New-ADOWorkItem -baseURL $adoConfiguration.baseUrl -accessToken $adoConfiguration.accessToken -wiType "Product Backlog Item" -payload $payload

    Write-Information -MessageData ("Work item id '{0}' linked to parent '{1}' with id '{2}'" -f $newWI.id, $adoConfiguration.clientName, $wiParent.id)
    # // STOP creating new PBI //
} else {
    Write-Warning ("Work item with title '{0}' already exists and is not closed or removed" -f $wiTitle)
    Write-Warning ("Please consider skipping this check by updating the pipeline environment variable '{0}' in the file: {1}/{2}/{3}" -f "cdm_check_skip_until", $env:CDM_CHECKS_DIRECTORY, $adoConfiguration.checkName , "pipeline-variables.yml")

    Write-Information -MessageData ("Work item Id: {0}" -f $wiPBIs.workItems.id)
}

Pop-Location
