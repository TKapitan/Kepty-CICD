##################################################################################################################
##################################################################################################################
######                                                                                                      ######
######    Tomas Kapitan, Kepty                                                                              ######
######    Version: 1.0.0.1                                                                                  ######
######                                                                                                      ######
##################################################################################################################
##################################################################################################################

Param(
    [Parameter(Mandatory=$true)]
    [string] $Kepty_changeFileLocation,
    [string] $Kepty_targetBranchForChanges = 'test',
    [string] $Kepty_commitMessageForChanges = 'Automatic Bulk Repository Update'
)
. (Join-Path $PSScriptRoot "Read-Settings.ps1")

'Loading change requests - ' + $Kepty_changeFileLocation
if (-not (Test-Path -Path $Kepty_changeFileLocation -PathType Leaf)) {
    'Change request file not found - ' + $Kepty_changeFileLocation
    return;
}
'Change requests loaded - ' + $Kepty_changeFileLocation

Function Test-File {
    [cmdletbinding()]
    Param (
        [string]$Kepty_filePath,
        [bool]$Kepty_shouldExists = $false,
        [bool]$Kepty_failIfNot = $false
    ) 
    Process {
        if (-not $Kepty_shouldExists) {
            if (Test-Path -Path $Kepty_filePath -PathType Leaf -ErrorAction Stop) {
                if ($Kepty_failIfNot) {
                    throw 'File ' + $Kepty_filePath + ' already exists'
                }
                return $false;
            }
            return $true;
        }
        if (-not (Test-Path -Path $Kepty_filePath -PathType Leaf -ErrorAction Stop)) {
            if ($Kepty_failIfNot) {
                throw 'File ' + $Kepty_filePath + ' does not exist'
            }
            return $false;
        }
        
        $Kepty_fileContent = (Get-Content $Kepty_filePath -Raw -ErrorAction Stop) 
        if ($null -eq $Kepty_fileContent) {
            if ($Kepty_failIfNot) {
                throw 'File ' + $Kepty_filePath + ' is empty'
            }
            return $false;
        }
        return $true;
    }
}
Function Test-File-Contains {
    [cmdletbinding()]
    Param (
        $Kepty_fileContent,
        [string]$Kepty_findString,
        [string]$Kepty_filePath,
        [bool]$Kepty_failIfNotFound = $false
    ) 
    Process {
        if (-not $Kepty_fileContent -imatch $Kepty_findString) {
            if ($Kepty_failIfNotFound) {
                throw 'String ' + $Kepty_findString + ' was not found in ' + $Kepty_filePath + ' (' + $Kepty_fileContent + ')'
            }
            return $false;
        }
        return $true;
    }
}
Function Test-Change-Request {
    [cmdletbinding()]
    Param (
        $Kepty_changeRequestContent,
        [ChangeRequestType]$Kepty_changeRequestAction
    ) 
    Process {
        Test-Has-Value -value $Kepty_changeRequestContent.failIfNotFound -caption '$Kepty_changeRequestContent.failIfNotFound'
        switch ($Kepty_changeRequestAction) {
            ([ChangeRequestType]::UpdateFile) {
                Test-Has-Value -value $Kepty_changeRequestContent.relativePath -caption '$Kepty_changeRequestContent.relativePath'
                Test-Has-Value -value $Kepty_changeRequestContent.relativePathFilter -caption '$Kepty_changeRequestContent.relativePathFilter'
                Test-Has-Value -value $Kepty_changeRequestContent.findString -caption '$Kepty_changeRequestContent.findString'
                Test-Has-Value -value $Kepty_changeRequestContent.replaceBy -caption '$Kepty_changeRequestContent.replaceBy'
            }
            ([ChangeRequestType]::RemoveFromFile) {
                Test-Has-Value -value $Kepty_changeRequestContent.relativePath -caption '$Kepty_changeRequestContent.relativePath'
                Test-Has-Value -value $Kepty_changeRequestContent.relativePathFilter -caption '$Kepty_changeRequestContent.relativePathFilter'
                Test-Has-Value -value $Kepty_changeRequestContent.findString -caption '$Kepty_changeRequestContent.findString'
            }
            ([ChangeRequestType]::RemoveLineFromFile) {
                Test-Has-Value -value $Kepty_changeRequestContent.relativePath -caption '$Kepty_changeRequestContent.relativePath'
                Test-Has-Value -value $Kepty_changeRequestContent.relativePathFilter -caption '$Kepty_changeRequestContent.relativePathFilter'
                Test-Has-Value -value $Kepty_changeRequestContent.findString -caption '$Kepty_changeRequestContent.findString'
            }
            ([ChangeRequestType]::RemoveBlockFromFile) {
                Test-Has-Value -value $Kepty_changeRequestContent.relativePath -caption '$Kepty_changeRequestContent.relativePath'
                Test-Has-Value -value $Kepty_changeRequestContent.relativePathFilter -caption '$Kepty_changeRequestContent.relativePathFilter'
                Test-Has-Value -value $Kepty_changeRequestContent.fromString -caption '$Kepty_changeRequestContent.fromString'
                Test-Has-Value -value $Kepty_changeRequestContent.toString -caption '$Kepty_changeRequestContent.toString'
            }
            ([ChangeRequestType]::CreateFile) {
                Test-Has-Value -value $Kepty_changeRequestContent.relativePath -caption '$Kepty_changeRequestContent.relativePath'
                Test-Has-Value -value $Kepty_changeRequestContent.newFileFullPath -caption '$Kepty_changeRequestContent.newFileFullPath'
            }
            ([ChangeRequestType]::DeleteFile) {
                Test-Has-Value -value $Kepty_changeRequestContent.relativePath -caption '$Kepty_changeRequestContent.relativePath'
            }
            ([ChangeRequestType]::ReplaceFile) {
                Test-Has-Value -value $Kepty_changeRequestContent.relativePath -caption '$Kepty_changeRequestContent.relativePath'
                Test-Has-Value -value $Kepty_changeRequestContent.newFileFullPath -caption '$Kepty_changeRequestContent.newFileFullPath'
            }
        }
    }
}
Function Test-Has-Value {
    [cmdletbinding()]
    Param (
        [string]$Kepty_value,
        [string]$Kepty_caption
    ) 
    Process {
        if ($null -eq $Kepty_value -or $Kepty_value -eq '') {
            throw $Kepty_caption + ' must have a value'
        }
    }
}
Function Replace-In-File {
    [cmdletbinding()]
    Param (
        [string]$Kepty_filePath,
        [string]$Kepty_findString,
        [string]$Kepty_replaceBy,
        [bool]$Kepty_failIfNotFound = $false
    ) 
    Process {
        if (-not (Test-File -filePath $Kepty_filePath -shouldExists $true -failIfNot $Kepty_failIfNotFound)) {
            return
        }
        $Kepty_fileContent = (Get-Content $Kepty_filePath -Raw -ErrorAction Stop)
        if (-not (Test-File-Contains -fileContent $Kepty_fileContent -findString $Kepty_findString -filePath $Kepty_filePath -failIfNotFound $Kepty_failIfNotFound)) {
            return
        }
        'Replacing ' + $Kepty_findString + ' by ' + $Kepty_replaceBy + ' in ' + $Kepty_filePath
        $Kepty_fileContent.replace($Kepty_findString, $Kepty_replaceBy) | Set-Content $Kepty_filePath -NoNewline -ErrorAction Stop
    }
}
Function Create-File {
    [cmdletbinding()]
    Param (
        $Kepty_targetFilePath,
        $Kepty_sourceFilePath,
        [bool]$Kepty_failIfNotFound = $false
    ) 
    Process {
        if (-not (Test-File -filePath $Kepty_targetFilePath -shouldExists $false -failIfNot $Kepty_failIfNotFound)) {
            return
        }
        if (-not (Test-File -filePath $Kepty_sourceFilePath -shouldExists $true -failIfNot $true)) {
            return
        }
        $Kepty_fileContent = (Get-Content $Kepty_filePath -Raw -ErrorAction Stop)
        if (-not (Test-File-Contains -fileContent $Kepty_fileContent -findString $Kepty_findString -filePath $Kepty_filePath -failIfNotFound $Kepty_failIfNotFound)) {
            return
        }
        Copy-Item $Kepty_sourceFilePath -Destination $Kepty_targetFilePath -ErrorAction Stop
    }
}
Function Replace-File {
    [cmdletbinding()]
    Param (
        $Kepty_targetFilePath,
        $Kepty_sourceFilePath,
        [bool]$Kepty_failIfNotFound = $false
    ) 
    Process {
        if (-not (Test-File -filePath $Kepty_targetFilePath -shouldExists $true -failIfNot $Kepty_failIfNotFound)) {
            return
        }
        if (-not (Test-File -filePath $Kepty_sourceFilePath -shouldExists $true -failIfNot $true)) {
            return
        }
        Copy-Item $Kepty_sourceFilePath -Destination $Kepty_targetFilePath -ErrorAction Stop
    }
}
Function Remove-File {
    [cmdletbinding()]
    Param (
        $Kepty_targetFilePath,
        [bool]$Kepty_failIfNotFound = $false
    ) 
    Process {
        'Deleting file ' + $Kepty_targetFilePath
        if (-not (Test-File -filePath $Kepty_targetFilePath -shouldExists $true -failIfNot $Kepty_failIfNotFound)) {
            return
        }
        Remove-Item $Kepty_targetFilePath -ErrorAction Stop
    }
}
Function Remove-Line-From-File {
    [cmdletbinding()]
    Param (
        $Kepty_filePath,
        $Kepty_findString,
        [bool]$Kepty_failIfNotFound = $false
    ) 
    Process {
        $Kepty_findString = [Regex]::Escape($Kepty_findString) 
        if (-not (Test-File -filePath $Kepty_filePath -shouldExists $true -failIfNot $Kepty_failIfNotFound)) {
            return
        }
        $Kepty_fileContent = (Get-Content $Kepty_filePath -Raw -ErrorAction Stop)
        if (-not (Test-File-Contains -fileContent $Kepty_fileContent -findString $Kepty_findString -filePath $Kepty_filePath -failIfNotFound $Kepty_failIfNotFound)) {
            return
        }
        'Removing whole line containing ' + $Kepty_findString + ' in ' + $Kepty_filePath
        Set-Content -Path $Kepty_filePath -Value (Get-Content -Path $Kepty_filePath -ErrorAction Stop | Select-String -Pattern $Kepty_findString -NotMatch -ErrorAction Stop) -ErrorAction Stop
    }
}
Function Remove-Block-From-File {
    [cmdletbinding()]
    Param (
        $Kepty_filePath,
        $Kepty_fromString,
        $Kepty_toString,
        [bool]$Kepty_failIfNotFound = $false
    ) 
    Process {
        $Kepty_findString = [Regex]::Escape($Kepty_findString) 
        if (-not (Test-File -filePath $Kepty_filePath -shouldExists $true -failIfNot $Kepty_failIfNotFound)) {
            return
        }
        $Kepty_fileContent = (Get-Content $Kepty_filePath -Raw -ErrorAction Stop)
        if (-not (Test-File-Contains -fileContent $Kepty_fileContent -findString $Kepty_fromString -filePath $Kepty_filePath -failIfNotFound $Kepty_failIfNotFound)) {
            return
        }
        if (-not (Test-File-Contains -fileContent $Kepty_fileContent -findString $Kepty_toString -filePath $Kepty_filePath -failIfNotFound $Kepty_failIfNotFound)) {
            return
        }
        'Removing whole block from ' + $Kepty_findString + ' to ' + $Kepty_toString + ' in ' + $Kepty_filePath
        Set-Content -Path $Kepty_filePath -Value (
            Get-Content $Kepty_filePath -ErrorAction Stop | Where-Object { 
                if (-not $Kepty_changedValue) {
                    $Kepty_keep = $true
                }
                if ( $_.Contains($Kepty_fromString) ) {
                    $Kepty_changedValue = $true
                    $Kepty_keep = $false
                }
                elseif ( -not $Kepty_keep -and $_.Contains($Kepty_toString) ) {
                    $Kepty_changedValue = $true
                    $Kepty_keep = $true
                }
                $Kepty_keep
            }
        ) -ErrorAction Stop
    }
}

$Kepty_newProcessedDefinition = ConvertFrom-Json @"
{
    "id": 0,
    "state": "",
    "details": "",
    "datetime": 0
}
"@

enum ChangeRequestType {
    UpdateFile = 1
    RemoveFromFile = 2
    RemoveLineFromFile = 5
    RemoveBlockFromFile = 50
    CreateFile = 100
    ReplaceFile = 105
    DeleteFile = 110
    Unsupported = 999
}

$Kepty_processedChangeFileLocation = (Join-Path $PSScriptRoot '/ProcessedChangeRequests.json')
$Kepty_changeRequests = Get-Content $Kepty_changeFileLocation | Out-String | ConvertFrom-Json
if (-not (Test-Path -Path $Kepty_processedChangeFileLocation -PathType Leaf -ErrorAction Stop)) {
    $Kepty_processedChangeRequests = ('[]' | ConvertFrom-Json)
}
else {
    if ($Null -eq (Get-Content $Kepty_processedChangeFileLocation)) {
        $Kepty_processedChangeRequests = ('[]' | ConvertFrom-Json)
    }
    else {
        $Kepty_processedChangeRequests = (Get-Content $Kepty_processedChangeFileLocation | Out-String | ConvertFrom-Json)
    }
}
'Already processed requests: ' + $Kepty_processedChangeRequests
foreach ($Kepty_changeRequest in $Kepty_changeRequests) {
    switch ($Kepty_changeRequest.action) {
        'updateFile' {
            $Kepty_changeRequestAction = [ChangeRequestType]::UpdateFile
        }
        'removeFromFile' {
            $Kepty_changeRequestAction = [ChangeRequestType]::RemoveFromFile
        }
        'removeLineFromFile' {
            $Kepty_changeRequestAction = [ChangeRequestType]::RemoveLineFromFile
        }
        'removeBlockFromFile' {
            $Kepty_changeRequestAction = [ChangeRequestType]::RemoveBlockFromFile
        }
        'createFile' {
            $Kepty_changeRequestAction = [ChangeRequestType]::CreateFile
        }
        'deleteFile' {
            $Kepty_changeRequestAction = [ChangeRequestType]::DeleteFile
        }
        'replaceFile' {
            $Kepty_changeRequestAction = [ChangeRequestType]::ReplaceFile
        }
        default {
            $Kepty_changeRequestAction = [ChangeRequestType]::Unsupported
        }
    }

    if ($Kepty_changeRequestAction -eq [ChangeRequestType]::Unsupported) {
        'Skipping change request #' + $Kepty_changeRequest.id + ' as it is of unsupported change request type ' + $Kepty_changeRequest.action
        continue
    }

    $Kepty_processedRequest = $Kepty_processedChangeRequests | Where-Object { $_.id -eq $Kepty_changeRequest.id } -ErrorAction Stop
    if ($null -eq $Kepty_processedRequest.id) {
        if (-not [bool]($Kepty_changeRequest.PSobject.Properties.name -match "failIfNotFound")) {
            $Kepty_changeRequest | Add-Member -Name 'failIfNotFound' -Type NoteProperty -Value $false
        }
        elseif ($null -eq $Kepty_changeRequest.failIfNotFound) {
            $Kepty_changeRequest.failIfNotFound = $false
        }

        Test-Change-Request -changeRequestContent $Kepty_changeRequest
        'Processing change request #' + $Kepty_changeRequest.id

        $Kepty_newlyProcessedRequest = $Kepty_newProcessedDefinition.PSObject.Copy()
        $Kepty_newlyProcessedRequest.id = $Kepty_changeRequest.id
        try {
            if ($Kepty_changeRequestAction -in @(([ChangeRequestType]::UpdateFile), ([ChangeRequestType]::RemoveFromFile), ([ChangeRequestType]::RemoveLineFromFile), ([ChangeRequestType]::RemoveBlockFromFile))) {
                $Kepty_foundFiles = Get-ChildItem (Join-Path $PSScriptRoot $Kepty_changeRequest.relativePath) -Filter $Kepty_changeRequest.relativePathFilter -Recurse -ErrorAction Stop | Where-Object { ! $_.PSIsContainer } -ErrorAction Stop
                'Found ' + ( $Kepty_foundFiles | Measure-Object ).Count + ' files'
                if (( $Kepty_foundFiles | Measure-Object ).Count -eq 0) {
                    throw 'No files found'
                }
                foreach ($Kepty_file in $Kepty_foundFiles) {
                    '(A) Processing file: ' + $Kepty_file.FullName + ' with action ' + $Kepty_changeRequestAction
                    switch ($Kepty_changeRequestAction) {
                        ([ChangeRequestType]::UpdateFile) {
                            Replace-In-File -filePath $Kepty_file.FullName -findString $Kepty_changeRequest.findString -replaceBy $Kepty_changeRequest.replaceBy -failIfNotFound $Kepty_changeRequest.failIfNotFound
                        }
                        ([ChangeRequestType]::RemoveFromFile) {
                            Replace-In-File -filePath $Kepty_file.FullName -findString $Kepty_changeRequest.findString -replaceBy '' -failIfNotFound $Kepty_changeRequest.failIfNotFound
                        }
                        ([ChangeRequestType]::RemoveLineFromFile) {
                            Remove-Line-From-File -filePath $Kepty_file.FullName -findString $Kepty_changeRequest.findString -failIfNotFound $Kepty_changeRequest.failIfNotFound
                        }
                        ([ChangeRequestType]::RemoveBlockFromFile) {
                            Remove-Block-From-File -filePath $Kepty_file.FullName -fromString $Kepty_changeRequest.fromString -toString $Kepty_changeRequest.toString -failIfNotFound $Kepty_changeRequest.failIfNotFound
                        }
                    }
                }
            }
            elseif ($Kepty_changeRequestAction -in @(([ChangeRequestType]::CreateFile), ([ChangeRequestType]::DeleteFile), ([ChangeRequestType]::ReplaceFile))) {
                '(B) Processing file: ' + $Kepty_file.FullName + ' with action ' + $Kepty_changeRequestAction
                switch ($Kepty_changeRequestAction) {
                    ([ChangeRequestType]::CreateFile) {
                        Create-File -targetFilePath (Join-Path $PSScriptRoot $Kepty_changeRequest.relativePath) -sourceFilePath $Kepty_changeRequest.newFileFullPath -failIfNotFound $Kepty_changeRequest.failIfNotFound
                    }
                    ([ChangeRequestType]::DeleteFile) {
                        Remove-File -targetFilePath (Join-Path $PSScriptRoot $Kepty_changeRequest.relativePath) -failIfNotFound $Kepty_changeRequest.failIfNotFound
                    }
                    ([ChangeRequestType]::ReplaceFile) {
                        Replace-File -targetFilePath (Join-Path $PSScriptRoot $Kepty_changeRequest.relativePath) -sourceFilePath $Kepty_changeRequest.newFileFullPath -failIfNotFound $Kepty_changeRequest.failIfNotFound
                    }
                }
            }
            $Kepty_newlyProcessedRequest.state = "success"
            $Kepty_newlyProcessedRequest.details = ""
        }
        catch {
            $Kepty_newlyProcessedRequest.state = "error"
            $Kepty_newlyProcessedRequest.details = $_
        }
        $Kepty_newlyProcessedRequest.datetime = Get-Date -format "yyyy-dd-MM HH:mm:ss"
        $Kepty_processedChangeRequests += $Kepty_newlyProcessedRequest
    }
}

'Changes completed. Storing processed changes...'

$Kepty_processedChangeRequests | ConvertTo-Json -depth 2 | Set-Content $Kepty_processedChangeFileLocation

'Processed changes stored. Commiting changes...'
Set-Location $PSScriptRoot
$env:GIT_REDIRECT_STDERR = '2>&1'
git config credential.useHttpPath true
git add .
git commit -m $Kepty_commitMessageForChanges
'Changes commited. Pushing to remote repository...'
git push origin HEAD:$Kepty_targetBranchForChanges
