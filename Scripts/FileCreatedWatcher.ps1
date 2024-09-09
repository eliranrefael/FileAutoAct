$logFilePath = "$PSScriptRoot\..\logoutput.log"
#Folder path to watch
$FolderToWatch = "$PSScriptRoot\..\test"
$FileTypeFilter = "*"
$IncludeSubdirectories = $false
$AttributeFilter = [IO.NotifyFilters]::FileName

. New-Item -Path "$FolderToWatch" -ItemType Directory -Force

# Import the Process-File function from the external file
. "$PSScriptRoot\FormatFile.ps1"

try {

    #Initialize FileCreatedWatcher
    $FileCreatedWatcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
        Path                  = $FolderToWatch
        Filter                = $FileTypeFilter
        IncludeSubdirectories = $IncludeSubdirectories
        NotifyFilter          = $AttributeFilter
    }

    
    #Register event handler   
    $Handler = Register-ObjectEvent -InputObject $FileCreatedWatcher -EventName Created -Action {
        $EventDetails = $event.SourceEventArgs
        $FileName = $EventDetails.Name
        Write-Output "File $FileName has been created" | Out-file -FilePath "$logFilePath" -Append
        $FilePath = $EventDetails.FullPath
        Format-File -FilePath $FilePath
    }

    $FileCreatedWatcher.EnableRaisingEvents = $true
    Write-Output "Start Watching $FolderToWatch" | Out-file -FilePath "$logFilePath" -Append

    do {
        Wait-Event -Timeout 10
    }while ($true)
}
finally {
    $FileCreatedWatcher.EnableRaisingEvents = $false
    Unregister-Event -SourceIdentifier Created
    $Handler | Remove-Job
    $FileCreatedWatcher.Dispose()

    Write-Output "Job terminated, Cleanup is done" | Out-file -FilePath "$logFilePath" -Append
}