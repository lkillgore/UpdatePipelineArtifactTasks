# Update Pipeline Artifact Tasks

usage:
`.\QueryAllDefinitionsUsingDownloadBuildArtifacts.ps1 <Azure_DevOps_Organization_URL> <PAT_Token> [-inspect]`

This script will find all the build definitions that use the 'Download Build Artifacts' task.  The results can be used in conjuction with the script below.  If the `-inspect` flag is used, then the definition will be loaded to see if the task is `enabled` or not.

usage:
`.\UpdateDefinitionToPipelineArtifacts.ps1 <Azure_DevOps_Organization_URL> <Definition_Id> <PAT_Token>`

This script will change any active existing 'Publish Build Artifacts' task and change it to 'Publish Pipeline Artifacts' tasks.
