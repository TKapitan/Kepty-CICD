##################################################################################################################
##################################################################################################################
######                                                                                                      ######
######    Tomas Kapitan, Kepty                                                                              ######
######    Version: 1.0.0.1                                                                                  ######
######                                                                                                      ######
##################################################################################################################
##################################################################################################################

Param(
    [string] $version = ""
)

$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"

$agentName = $ENV:AGENT_NAME
$settings = (Get-Content (Join-Path $PSScriptRoot "settings.json") | ConvertFrom-Json)
if ("$version" -eq "") {
    $version = $settings.versions[0].version
    Write-Host "Version not defined, using $version"
}

$buildversion = $settings.versions | Where-Object { $_.version -eq $version }
if ($buildversion) {
    Write-Host "Set artifact = $($buildVersion.artifact)"
    Set-Variable -Name "artifact" -Value $buildVersion.artifact
}
else {
    throw "Unknown version: $version"
}

$pipelineName = "$($settings.Name)-$version"
Write-Host "Set pipelineName = $pipelineName"

if ($agentName) {
    $containerName = "$($agentName -replace '[^a-zA-Z0-9---]', '')-$($pipelineName -replace '[^a-zA-Z0-9---]', '')".ToLowerInvariant()
}
else {
    $containerName = "$($pipelineName.Replace('.','-') -replace '[^a-zA-Z0-9---]', '')".ToLowerInvariant()
}
Write-Host "Set containerName = $containerName"
Write-Host "##vso[task.setvariable variable=containerName]$containerName"

"Kepty_imageName", "Kepty_licenseFileLocation", "Kepty_failOn", "Kepty_includedPreProcessorSymbols", "Kepty_preProcessorSymbolsVersion", "Kepty_publishAppFileLocation", "Kepty_sourceAppAppJsonFileLocation", "Kepty_sourceTestAppJsonFileLocation", "country", "installApps", "installTestApps", "previousApps", "appSourceCopMandatoryAffixes", "appSourceCopSupportedCountries", "appFolders", "testFolders", "memoryLimit", "additionalCountries", "genericImageName", "vaultNameForLocal", "bcContainerHelperVersion" | ForEach-Object {
    $str = ""
    if ($_ -eq "Kepty_imageName") {
        $str = "bcimage"
    }
    if ($_ -eq "Kepty_failOn") {
        $str = "error"
    }
    if ($buildversion.PSObject.Properties.Name -eq $_) {
        $str = $buildversion."$_"
    }
    elseif ($settings.PSObject.Properties.Name -eq $_) {
        $str = $settings."$_"
    }
    Write-Host "Set $_ = '$str'"
    Set-Variable -Name $_ -Value "$str"
}

"Kepty_validateAgainstPreviousApp", "installTestRunner", "installTestFramework", "installTestLibraries", "installPerformanceToolkit", "enableCodeCop", "enableAppSourceCop", "enablePerTenantExtensionCop", "enableUICop", "doNotSignApps", "doNotRunTests", "cacheImage", "CreateRuntimePackages" | ForEach-Object {
    $str = "False"
    if ($buildversion.PSObject.Properties.Name -eq $_) {
        $str = $buildversion."$_"
    }
    elseif ($settings.PSObject.Properties.Name -eq $_) {
        $str = $settings."$_"
    }
    Write-Host "Set $_ = $str"
    Set-Variable -Name $_ -Value ($str -eq "True")
}
