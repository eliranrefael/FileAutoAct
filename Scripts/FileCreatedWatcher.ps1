#Folder path to watch
$FolderToWatch = "$PSScriptRoot\..\test"
$FileTypeFilter = "*"
$IncludeSubdirectories = $false
$AttributeFilter = [IO.NotifyFilters]::FileName

. New-Item -Path "$FolderToWatch" -ItemType Directory -Force

# Import the Process-File function from the external file
Import-Module -Name "$PSScriptRoot\Modules\FormatFile.psm1"
Import-Module -Name "$PSScriptRoot\Modules\WriteLog.psm1"
$global:LogFilePath = "$PSScriptRoot\..\logoutput.log"
Clear-Content -Path $global:LogFilePath -ErrorAction SilentlyContinue

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
        Write-Log -m "File $FileName has been created"
        $FilePath = $EventDetails.FullPath
        Format-File -FilePath $FilePath
    }

    $FileCreatedWatcher.EnableRaisingEvents = $true
    Write-Log -m "Start Watching $FolderToWatch" 

    do {
        Wait-Event -Timeout 10
    }while ($true)
}
finally {
    $FileCreatedWatcher.EnableRaisingEvents = $false

    try {
        if ($Handler -is [System.Management.Automation.Job]) {
            $Handler | Stop-Job
            $Handler | Remove-Job
        }
    }
    catch {
        Write-Host "warning"
    }

    $FileCreatedWatcher.Dispose()

    Write-Log -m "Job terminated, Cleanup is done"
}