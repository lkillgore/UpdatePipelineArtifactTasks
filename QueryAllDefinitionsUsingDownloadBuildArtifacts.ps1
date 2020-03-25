param (
    [Parameter(Mandatory = $true)]
    [string] $accountUrl,

    [Parameter(Mandatory = $true)]
    [string] $pat,

    [Parameter(Mandatory = $false)]
    [switch] $inspect
)

# Create the VSTS auth header
$base64authinfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$vstsAuthHeader = @{"Authorization"="Basic $base64authinfo"}
$allHeaders = $vstsAuthHeader + @{"Content-Type"="application/json"; "Accept"="application/json"}

$publishBuildArtifactsTask = "2ff763a7-ce83-4e1f-bc89-0ae63477cebe"

try
{
    Write-Output "Fetching definition list"

    $continuationToken = ""
    do
    {
        $url = "$($accountUrl)/_apis/build/definitions?api-version=5.1&taskIdFilter=$($publishBuildArtifactsTask)&queryOrder=lastModifiedAscending"
        if ($continuationToken.Length -gt 0)
        {
            $url += "&continuationToken=$($continuationToken)"
        }

        $result = Invoke-WebRequest -Headers $allHeaders -Method GET $url
        # Write-Output $result.Content

        if ($result.StatusCode -ne 200)
        {
            Write-Output $result.Content
            throw "Failed to query definitions"
        }

        $continuationToken = $result.Headers.'X-MS-ContinuationToken'

        $definitions = $result.Content | ConvertFrom-Json
        Write-Output "Found $($definitions.count) definitions"

        $foundFromInspection = 0
        foreach ($definition in $definitions.value)
        {

            if ($inspect)
            {
                $getResult = Invoke-WebRequest -Headers $allHeaders -Method GET "$($accountUrl)/_apis/build/definitions/$($definition.id)?api-version=5.1"
                # Write-Output $result.Content
            
                if ($getResult.StatusCode -ne 200)
                {
                    Write-Output $getResult.Content
                    throw "Failed to query definition"
                }
            
                $defintionContent = $getResult.Content | ConvertFrom-Json -Depth 32
                foreach ($phase in $defintionContent.process.phases)
                {
                    # Write-Output "Looking through phase $($phaseCount)"
            
                    # Write-Output "Looking for build artifact steps/tasks"
                    for ($stepIdx = 0; $stepIdx -lt $phase.steps.Length; $stepIdx++)
                    {
                        $step = $phase.steps[$stepIdx]
            
                        # Write-Output "Step: '$($step)' Task: '$($step.task)' id: '$($step.task.id)'"
                        if ($step.task.id -eq $publishBuildArtifactsTask -And $step.enabled)
                        {
                            Write-Output "Definition Id: '$($definition.id)' Name: '$($definition.name)'"
                            $foundFromInspection++
                        }
                    }
                }
            }
            else
            {
                Write-Output "Definition Id: '$($definition.id)' Name: '$($definition.name)'"
            }
        }

        if ($foundFromInspection -gt 0)
        {
            Write-Output "Found from inspection: $($foundFromInspection)"
        }

    } while ($continuationToken.Length -gt 0)
}
catch {
    throw "Failed to query jobs: $_"
}