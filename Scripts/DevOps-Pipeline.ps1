##################################################################################################################
##################################################################################################################
######                                                                                                      ######
######    Tomas Kapitan, Kepty                                                                              ######
######    Version: 1.0.0.1                                                                                  ######
######                                                                                                      ######
##################################################################################################################
##################################################################################################################

Param(
    [Parameter(Mandatory = $true)]
    [string] $version,
    [Parameter(Mandatory = $false)]
    [int] $appBuild = 0,
    [Parameter(Mandatory = $false)]
    [int] $appRevision = 0,
    [Parameter(Mandatory = $false)]
    [ValidateSet('False', 'True')]
    [string] $validateAgainstPreviousApp = 'False'
)

$buildArtifactFolder = $ENV:BUILD_ARTIFACTSTAGINGDIRECTORY
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$baseFolder = (Get-Item (Join-Path $PSScriptRoot "..")).FullName
. (Join-Path $PSScriptRoot "Read-Settings.ps1") -version $version
. (Join-Path $PSScriptRoot "Install-BcContainerHelper.ps1") -bcContainerHelperVersion $bcContainerHelperVersion -genericImageName $genericImageName

$authContext = $null
$refreshToken = "$($ENV:BcSaasRefreshToken)"
$environmentName = "$($ENV:EnvironmentName)"
if ($refreshToken -and $environmentName) {
    $authContext = New-BcAuthContext -refreshToken $refreshToken
    if (Get-BcEnvironments -bcAuthContext $authContext | Where-Object { $_.Name -eq $environmentName -and $_.type -eq "Sandbox" }) {
        Remove-BcEnvironment -bcAuthContext $authContext -environment $environmentName
    }
    $countryCode = $artifact.Split('/')[3]
    New-BcEnvironment -bcAuthContext $authContext -environment $environmentName -countryCode $countrycode -environmentType "Sandbox" | Out-Null
    do {
        Start-Sleep -Seconds 10
        $baseApp = Get-BcPublishedApps -bcAuthContext $authContext -environment $environmentName | Where-Object { $_.Name -eq "Base Application" }
    } while (!($baseApp))
    $baseapp | Out-Host

    $artifact = Get-BCArtifactUrl `
        -country $countryCode `
        -version $baseApp.Version `
        -select Closest
    
    if ($artifact) {
        Write-Host "Using Artifacts: $artifact"
    }
    else {
        throw "No artifacts available"
    }
}

$params = @{}
$credential = New-Object pscredential 'admin', (ConvertTo-SecureString -String 'password' -AsPlainText -Force)
$insiderSasToken = "$ENV:insiderSasToken"
$Kepty_artifactType = "$ENV:Kepty_artifactType"
$Kepty_artifactVersion = "$ENV:Kepty_artifactVersion"
$codeSigncertPfxFile = "$ENV:CodeSignCertPfxFile"
if (!$doNotSignApps -and $codeSigncertPfxFile) {
    if ("$ENV:CodeSignCertPfxPassword" -ne "") {
        $codeSignCertPfxPassword = try { "$ENV:CodeSignCertPfxPassword" | ConvertTo-SecureString } catch { ConvertTo-SecureString -String "$ENV:CodeSignCertPfxPassword" -AsPlainText -Force }
        $params = @{
            "codeSignCertPfxFile"     = $codeSignCertPfxFile
            "codeSignCertPfxPassword" = $codeSignCertPfxPassword
        }
    }
    else {
        $codeSignCertPfxPassword = $null
    }
}

$allTestResults = "testresults*.xml"
$testResultsFile = Join-Path $baseFolder "TestResults.xml"
$testResultsFiles = Join-Path $baseFolder $allTestResults
if (Test-Path $testResultsFiles) {
    Remove-Item $testResultsFiles -Force
}

# Get proper version for onprem type
if (($Kepty_artifactType -eq '') -or (-not $artifact.Contains('{ARTIFACTTYPE}'))) {
    $Kepty_artifactType = 'Sandbox';
}

$artifactURL = $artifact.replace('{INSIDERSASTOKEN}', $insiderSasToken).replace('{ARTIFACTTYPE}', $Kepty_artifactType).replace('{COUNTRY}', $country).replace('{ARTIFACTVERSION}', $Kepty_artifactVersion);
if ($Kepty_artifactType -eq 'OnPrem') {
    $Kepty_artifactVersion = $Kepty_artifactVersion.Split('.');
    $Kepty_artifactVersion = $Kepty_artifactVersion[0] + '.' + $Kepty_artifactVersion[1];

    Write-Host "Determining onprem artifact $($country), $($Kepty_artifactType), $($Kepty_artifactVersion)";
    $artifactURL = Get-BCArtifactUrl -country $country -type $Kepty_artifactType -version $Kepty_artifactVersion;
    $artifactURL = $artifactURL.Replace('https://bcartifacts.azureedge.net/', '/');
} 
Write-Host "Accessing $($artifactURL)";

# Find dependencies
Import-Module (Join-Path $PSScriptRoot "Kepty-Pipelines.ps1")

# Scan APP
Write-Host "Identifying App dependencies..."
$Kepty_appJsonFilePath = (Join-Path $PSScriptRoot $Kepty_sourceAppAppJsonFileLocation);
Write-Host "Looking for " $Kepty_appJsonFilePath;
# Find app.json 
$Kepty_appFile = Get-AppJsonFile -sourceAppJsonFileLocation $Kepty_appJsonFilePath
# Get all dependencies for specific extension
$Kepty_installApps = $(Get-AllBCDependencies -targetSharedFolder $Kepty_publishAppFileLocation -appFile $Kepty_appFile -excludeExtensionID '')
Write-Host "App dependencies: $Kepty_installApps"

# Scan TEST
Write-Host "Identifying Test dependencies..."
$Kepty_appJsonFilePath = (Join-Path $PSScriptRoot $Kepty_sourceTestAppJsonFileLocation);
Write-Host "Looking for " $Kepty_appJsonFilePath;
# Find app.json 
$Kepty_appFileTest = Get-AppJsonFile -sourceAppJsonFileLocation $Kepty_appJsonFilePath
# Get all dependencies for specific extension
$Kepty_installTestApps = $(Get-AllBCDependencies -targetSharedFolder $Kepty_publishAppFileLocation -appFile $Kepty_appFileTest -excludeExtensionID $Kepty_appFile.id)
Write-Host "Test dependencies: $Kepty_installTestApps"

# Scan APP previous app
$Kepty_previousApp = '';
if ($Kepty_validateAgainstPreviousApp) {
    Write-Host "Identifying previous app version..."
    $Kepty_previousApp = (Get-PreviousAppVersion -targetSharedFolder $Kepty_publishAppFileLocation -appFile $Kepty_appFile);
}
else {
    Write-Host "Skipping previous version lookup..."
}

$Kepty_preProcessorSymbols = '';
switch ($Kepty_preProcessorSymbolsVersion) {
    "Current" {
        $Kepty_preProcessorSymbols = "$($ENV:Kepty_PreProcessorSymbolsCurrent)"
    }
    "Next-Major" {
        $Kepty_preProcessorSymbols = "$($ENV:Kepty_PreProcessorSymbolsNextMajor)"
    }
}
Write-Host "Using $Kepty_preProcessorSymbols ($Kepty_preProcessorSymbolsVersion) preProcessor Symbols..."
if ($Kepty_preProcessorSymbols -ne '' -and $Kepty_includedPreProcessorSymbols -ne '') {
    $Kepty_preProcessorSymbols += ','
}
if ($Kepty_includedPreProcessorSymbols -ne '') {
    $Kepty_preProcessorSymbols += $Kepty_includedPreProcessorSymbols
    Write-Host "With included preprocessor symbols $Kepty_preProcessorSymbols..."
}

Run-AlPipeline @params `
    -pipelinename $pipelineName `
    -containerName $containerName `
    -imageName $Kepty_imageName `
    -bcAuthContext $authContext `
    -environment $environmentName `
    -artifact $artifactURL `
    -memoryLimit $memoryLimit `
    -baseFolder $baseFolder `
    -licenseFile $Kepty_licenseFileLocation `
    -installApps $Kepty_installApps `
    -installTestApps $Kepty_installTestApps `
    -previousApps $Kepty_previousApp `
    -appFolders $appFolders `
    -testFolders $testFolders `
    -doNotRunTests:$doNotRunTests `
    -testResultsFile $testResultsFile `
    -testResultsFormat 'JUnit' `
    -installTestRunner:$installTestRunner `
    -installTestFramework:$installTestFramework `
    -installTestLibraries:$installTestLibraries `
    -installPerformanceToolkit:$installPerformanceToolkit `
    -credential $credential `
    -enableCodeCop:$enableCodeCop `
    -enableAppSourceCop:$enableAppSourceCop `
    -enablePerTenantExtensionCop:$enablePerTenantExtensionCop `
    -enableUICop:$enableUICop `
    -azureDevOps:$true `
    -gitLab:$false `
    -gitHubActions:$false `
    -failOn $Kepty_failOn `
    -AppSourceCopMandatoryAffixes $appSourceCopMandatoryAffixes `
    -AppSourceCopSupportedCountries $appSourceCopSupportedCountries `
    -additionalCountries $additionalCountries `
    -buildArtifactFolder $buildArtifactFolder `
    -CreateRuntimePackages:$CreateRuntimePackages `
    -preProcessorSymbols $Kepty_preProcessorSymbols

Write-Host "##vso[task.setvariable variable=TestResults]$allTestResults"
