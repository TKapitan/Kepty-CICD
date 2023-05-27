##################################################################################################################
##################################################################################################################
######                                                                                                      ######
######    Tomas Kapitan, Kepty                                                                              ######
######    Version: 1.0.0.0                                                                                  ######
######                                                                                                      ######
##################################################################################################################
##################################################################################################################

. (Join-Path $PSScriptRoot "Read-Settings.ps1")
. (Join-Path $PSScriptRoot "Kepty-Pipelines.ps1")

Write-Host "Storing App file and app.json for: $Kepty_sourceAppAppJsonFileLocation";
    
foreach ($Kepty_appJsonFilePath in $Kepty_sourceAppAppJsonFileLocation.Split(',')) {
    Write-Host "Storing App file and app.json for: $Kepty_appJsonFilePath"
    $Kepty_appJsonFilePath = (Join-Path $PSScriptRoot $Kepty_appJsonFilePath);

    # Find app.json & target path
    $Kepty_appFile = Get-AppJsonFile -sourceAppJsonFileLocation $Kepty_appJsonFilePath
    $Kepty_targetPath = Get-AppTargetFilePath -targetSharedFolder $Kepty_publishAppFileLocation -extensionID $Kepty_appFile.id -extensionVersion $Kepty_appFile.version -findExisting 'false' -findPreviousVersion 'false'

    # Copy application file & app.json file to our shared folder
    $Kepty_newAppFileLocation = $Kepty_targetPath + (Get-AppFileName -publisher $Kepty_appFile.publisher -name $Kepty_appFile.name -version $Kepty_appFile.version);
    New-Item -ItemType File -Path $Kepty_newAppFileLocation -Force -Verbose
    Copy-Item (Get-AppSourceFileLocation -appFile $Kepty_appFile) $Kepty_newAppFileLocation
    Copy-Item $Kepty_appJsonFilePath ($Kepty_targetPath + 'app.json')
}
