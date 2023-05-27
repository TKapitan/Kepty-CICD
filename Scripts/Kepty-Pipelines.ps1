##################################################################################################################
##################################################################################################################
######                                                                                                      ######
######    Tomas Kapitan, Kepty                                                                              ######
######    Version: 1.0.0.2                                                                                  ######
######                                                                                                      ######
##################################################################################################################
##################################################################################################################

Function Get-AppJsonFile {
    [cmdletbinding()]
    Param (
        $sourceAppJsonFileLocation
    ) 
    Process {
        ## Find app.json
        $appFile = '';
        $PSDefaultParameterValues['*:Encoding'] = 'utf8'
        foreach ($appFilePath in $sourceAppJsonFileLocation) {
            if (Test-Path -Path $appFilePath -PathType Leaf) {
                Write-Host "Trying to load json file:" $appFilePath
                $appFile = (Get-Content $appFilePath | ConvertFrom-Json);
                break;
            }
        }
        if ($appFile -eq '') {
            throw "App.json file was not found for $($sourceAppJsonFileLocation).";
        }
        else {
            Write-Host "App.json found for $($appFilePath)"
        }
        return $appFile;
    }
}
Function Get-BCDependencies {
    [cmdletbinding()]
    Param (
        $appFile,
        $targetSharedFolder
    )
    Process {
        ## Lookup dependencies
        $dependencies = $appFile.dependencies;
        if ($dependencies) {
            $listOfDependencies = '';
            foreach ($dependency in $dependencies) {
                if ($listOfDependencies -ne '') {
                    $listOfDependencies += ',';
                }
                $listOfDependencies += $targetSharedFolder + $dependency.id + '_' + $dependency.version + '.app';        
            }
        }
        Write-Host "List of dependencies = $listOfDependencies"
    }
}
Function Get-AppSourceFileLocation {
    [cmdletbinding()]
    Param (
        $appFile
    )
    Process {
        return (Join-Path $PSScriptRoot "../.output/") + (Get-AppFileName -publisher $appFile.publisher -name $appFile.name -version $appFile.version);
    }
}
Function Get-AppFileName {
    [cmdletbinding()]
    Param (
        [string]$publisher,
        [string]$name,
        [string]$version
    )
    Process {
        $fileName = $publisher + '_' + $name + '_' + $version + '.app';
        return $fileName.Split([IO.Path]::GetInvalidFileNameChars()) -join '';
    }
}
Function Get-AppTargetFilePath {
    [cmdletbinding()]
    Param (
        [string]$targetSharedFolder,
        [string]$extensionID,
        [string]$extensionVersion,
        [string]$findExisting,
        [string]$findPreviousVersion
    )
    Process {
        if ($findExisting -ne 'true') {
            return $targetSharedFolder + "apps\" + $extensionID + "\" + $extensionVersion + "\";
        }
        
        if (-not (Test-Path -Path ($targetSharedFolder + "apps\" + $extensionID) -PathType Container)) {
            throw $targetSharedFolder + "apps\" + $extensionID + " does not exists."
        }

        $usedAppVersion = '0.0.0.0';
        Write-Host "Requested version of" $extensionID "is" $extensionVersion;
        $sourceDirectoryContent = Get-ChildItem ($targetSharedFolder + "apps\" + $extensionID + "\") -Directory
        foreach ($currDir in $sourceDirectoryContent) {
            [string]$folderAppVersion = $currDir
            if ($findPreviousVersion -eq 'true') {
                if (([version]$folderAppVersion -gt [version]$usedAppVersion) -and ([version]$folderAppVersion -lt [version]$extensionVersion)) {
                    $usedAppVersion = $folderAppVersion
                }
            }
            else {
                if (([version]$folderAppVersion -gt [version]$usedAppVersion) -and ([version]$folderAppVersion -cge [version]$extensionVersion)) {
                    $usedAppVersion = $folderAppVersion
                }
            }
        }
        if ($usedAppVersion -eq '0.0.0.0') {
            if ($findPreviousVersion -eq 'true') {
                return '';
            }
            throw "Cannot find any version for " + $extensionID;
        } 
        Write-Host "Used version of" $extensionID "is" $usedAppVersion;
        return $targetSharedFolder + "apps\" + $extensionID + "\" + $usedAppVersion + "\";
    }
}
Function Get-PreviousAppVersion {
    [cmdletbinding()]
    Param (
        [string]$targetSharedFolder,
        $appFile
    )
    Process {
        $appsLocation = Get-AppTargetFilePath -targetSharedFolder $targetSharedFolder -extensionID $appFile.id -extensionVersion $appFile.version -findExisting 'true' -findPreviousVersion 'true';
        if ($appsLocation -eq '') {
            return '';
        }
        $previousAppFileLocation = $appsLocation + (Get-AppFileName -publisher $appFile.publisher -name $appFile.name -version $appFile.version);
        return $previousAppFileLocation;
    }
}
## Main function
Function Get-AllBCDependencies {
    [cmdletbinding()]
    Param (
        [string]$targetSharedFolder,
        [string]$excludeExtensionID,
        $appFile
    )
    Process {
        $listOfDependencies = ''
        foreach ($dependency in $appFile.dependencies) {
            if ($dependency.publisher -ne 'Microsoft') {
                Write-Host "Checking exlude extension ID:" $dependency.id "and" $excludeExtensionID
                if ($dependency.id -ne $excludeExtensionID) {
                    Write-Host "Path:" $targetSharedFolder ", id:" $dependency.id ", version:" $dependency.version
                    $appsLocation = Get-AppTargetFilePath -targetSharedFolder $targetSharedFolder -extensionID $dependency.id -extensionVersion $dependency.version -findExisting 'true' -findPreviousVersion 'false';
                    $dependencyAppContent = Get-AppJsonFile -sourceAppJsonFileLocation ($appsLocation + 'app.json');
                    $otherDependencies = Get-AllBCDependencies -targetSharedFolder $targetSharedFolder -appFile $dependencyAppContent -excludeExtensionID $excludeExtensionID
                
                    if ($otherDependencies -ne '') {
                        if ($listOfDependencies.IndexOf($otherDependencies) -eq -1) {
                            if ($listOfDependencies -ne '') {
                                $listOfDependencies += ','
                            }
                            $listOfDependencies += $otherDependencies
                        }
                    }
                    $dependencyAppFileLocation = $appsLocation + (Get-AppFileName -publisher $dependencyAppContent.publisher -name $dependencyAppContent.name -version $dependencyAppContent.version);
                    if ($listOfDependencies.IndexOf($dependencyAppFileLocation) -eq -1) {
                        if ($listOfDependencies -ne '') {
                            $listOfDependencies += ','
                        }
                        $listOfDependencies += ($dependencyAppFileLocation)
                    }
                }
            }
        }
        return $listOfDependencies;
    }
}
