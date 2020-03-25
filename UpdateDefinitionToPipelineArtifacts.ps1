param (
    [Parameter(Mandatory = $true)]
    [string] $accountUrl,

    [Parameter(Mandatory = $true)]
    [string] $definitionId,

    [Parameter(Mandatory = $true)]
    [string] $pat
)

# Create the VSTS auth header
$base64authinfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$pat"))
$vstsAuthHeader = @{"Authorization"="Basic $base64authinfo"}
$allHeaders = $vstsAuthHeader + @{"Content-Type"="application/json"; "Accept"="application/json"}

try
{
    Write-Output "Fetching definition $definitionId"

    $getResult = Invoke-WebRequest -Headers $allHeaders -Method GET "$($accountUrl)/_apis/build/definitions/$($definitionId)?api-version=5.1"
    Write-Output $result.Content

    if ($getResult.StatusCode -ne 200)
    {
        Write-Output $getResult.Content
        throw "Failed to query definition"
    }

    $requiresUpdate = $false
    $defintionContent = $getResult.Content | ConvertFrom-Json -Depth 32
    $phaseCount = 0
    $stepCount = 0
    foreach ($phase in $defintionContent.process.phases)
    {
        Write-Output "Looking through phase $($phaseCount)"
        $phaseCount++

        Write-Output "Looking for build artifact steps/tasks"
        $replacementSteps= [PSCustomObject]@()

        for ($stepIdx = 0; $stepIdx -lt $phase.steps.Length; $stepIdx++)
        {
            $stepCount++
            $step = $phase.steps[$stepIdx]

            # Write-Output "Step: '$($step)' Task: '$($step.task)' id: '$($step.task.id)'"
            if ($step.task.id -eq "2ff763a7-ce83-4e1f-bc89-0ae63477cebe" -And $step.enabled)
            {
                Write-Output "Found an enabled 'Publish Build Artifacts' task"
                $requiresUpdate = $true

                $artifactType = "filepath"
                if ($step.inputs.ArtifactType -eq "Container")
                {
                    $artifactType = "pipeline"
                }

                $replacementSteps += [PSCustomObject]@{
                    environment = $step.environment
                    enabled = $true
                    continueOnError = $step.continueOnError
                    alwaysRun = $step.alwaysRun
                    displayName = "Publish Pipeline Artifacts (Converted): $($step.displayName)"
                    timeoutInMinutes = $step.timeoutInMinutes
                    condition = $step.condition
                    task = @{
                        id = "ecdc45f6-832d-4ad9-b52b-ee49e94659be"
                        versionSpec = "1.*"
                        definitionType = "task"
                    }
                    inputs = @{
                        path = $step.inputs.PathtoPublish
                        artifactName = $step.inputs.ArtifactName
                        artifactType = $artifactType
                        fileSharePath = $step.inputs.TargetPath
                        parallel = $step.inputs.Parallel
                        parallelCount = $step.inputs.ParallelCount
                    }
                }

                # disable the existing step
                $step.enabled = $false
            }
            
            $replacementSteps += $step
        }

        $phase.steps = $replacementSteps
    }

    Write-Output "Looked through $($stepCount) steps"

    if ($requiresUpdate)
    {
        Write-Output "Updating definition"
        $defintionContent | add-member -Name "comment" -Value "Tool assisted conversion of 'PublishBuildArtifacts' to 'PublishPipelineArtifacts'" -MemberType NoteProperty
        $updateBody = $defintionContent | ConvertTo-Json -Depth 32
        
        # Write-Output $updateBody

        $updateResult = Invoke-WebRequest -Headers $allHeaders -Method PUT "$($accountUrl)/_apis/build/definitions/$($definitionId)?api-version=5.1" -Body $updateBody

        if ($updateResult.StatusCode -ne 200)
        {
            Write-Output $updateResult.Content
            throw "Failed to update definition '$($definitionId)'"
        }

        Write-Output "Successfully updated definition '$($definitionId)'"
    }
    else
    {
        Write-Output "Definition '$($definitionId)' does not require an update"
    }
}
catch {
    throw "Failed to query jobs: $_"
}