
$ErrorActionPreference = "Stop"

Push-Location -Path $PSScriptRoot

# dot-sourcing functions
. ../../powershell/functions/Find-ADOWorkItemsByQuery.ps1
. ../../powershell/functions/New-ADOWorkItem.ps1
. ../../powershell/functions/Get-ADOWorkItemById.ps1
. ../../powershell/functions/Link-ADOWorkItemToParent.ps1

$adoConfiguration.Add('clientName', $env:ADO_CLIENT_NAME)

$script:wiTitle = ("{0}: {1} {2} FAILED" -f $env:SYSTEM_DEFINITIONNAME, $env:SYSTEM_STAGEDISPLAYNAME, $env:SYSTEM_PHASEDISPLAYNAME)
$script:wiUserStoryQuery = ("Select [System.Id], [System.Title], [System.WorkItemType], [System.State] From WorkItems WHERE [System.WorkItemType] = 'User Story' AND [System.Title] = '{0}' AND [State] <> 'Closed' AND [State] <> 'Removed'" -f $wiTitle)

$script:wiUserStories = Find-ADOWorkItemsByQuery -baseURL $adoConfiguration.baseURL -systemAccessToken $adoConfiguration.accessToken -wiQuery $wiUserStoryQuery

if ($wiUserStories.workItems.Count -eq 0) {
    Write-Host ("Creating work item with title '{0}'" -f $wiTitle)
    
    $script:wiDescription = (
        "<a href='{0}{1}/_build/results?buildId={2}&view=logs&s={3}&j={4}'>Build: {5}</a>" -f $env:SYSTEM_COLLECTIONURI, $env:SYSTEM_TEAMPROJECT, $env:BUILD_BUILDID, $env:SYSTEM_STAGEID, $env:SYSTEM_JOBID, $env:BUILD_BUILDNUMBER
    )
    
    $script:newWI = New-ADOWorkItem -baseURL $adoConfiguration.baseURL -systemAccessToken $adoConfiguration.accessToken -wiTitle $wiTitle -wiDescription $wiDescription

    $script:wiThemeQuery = ("SELECT [System.Id], [System.Title], [System.WorkItemType], [System.State] FROM WorkItemLinks WHERE [Source].[System.Title] = '{0}' AND [Source].[System.WorkItemType] = 'Theme' AND [Source].[System.State] <> 'Closed' AND [Source].[System.State] <> 'Removed'" -f "Maintenance")
    $script:wiThemes = Find-ADOWorkItemsByQuery -baseURL $adoConfiguration.baseURL -systemAccessToken $adoConfiguration.accessToken -wiQuery $wiThemeQuery

    foreach ($wiThemeChildId in $wiThemes.workItemRelations.target.id) {
        $wiThemeChild = Get-ADOWorkItemById -baseURL $adoConfiguration.baseURL -systemAccessToken $adoConfiguration.accessToken -wiId $wiThemeChildId
        
        if ($wiThemeChild.fields.'System.Title' -eq $edSREClient) {
            foreach ($wiEpicChildLink in $wiThemeChild.relations | Where-Object {$_.rel -eq "System.LinkTypes.Hierarchy-Forward"}) {
            $wiEpicChild = Get-ADOWorkItemById -baseURL $adoConfiguration.baseURL -systemAccessToken $adoConfiguration.accessToken -wiId (Split-Path -Path $wiEpicChildLink.url -Leaf)
                
            if ($wiEpicChild.fields.'System.Title' -eq "Maintenance Planning") {
                    Link-ADOWorkItemToParent -baseURL $adoConfiguration.baseURL -systemAccessToken $adoConfiguration.accessToken -wiId $newWI.Id -wiParentId $wiEpicChild.id
                }
            }  
        }
    }

    Write-Host ("Work item Id: {0}" -f $newWI.id)

} else {
    Write-Warning ("Work item with title '{0}' already exists and is not closed or removed" -f $wiTitle)
    Write-Warning ("Please consider skipping this check by updating the pipeline environment variable '{0}' in the file: {1}/{2}/{3}" -f "cdm_check_skip_until", $env:CDM_CHECKS_DIRECTORY, $env:SYSTEM_PHASENAME, "pipeline-variables.yml")

    Write-Host ("Work item Id: {0}" -f $wiUserStories.workItems.id)
}

Pop-Location
