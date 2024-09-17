Import-Module -Name "$PSScriptRoot\Modules\FormatFile.psm1"
Import-Module -Name "$PSScriptRoot\Modules\WriteLog.psm1"

function Watch-File() {
    Param (
        #Path to watch for new files.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [Alias("t")]
        [string]$TargetPath,
        #Log file path.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("l")]
        [string]$LogFilePath = ".\logoutput.txt",
        #Log file path.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("f")]
        [string]$FileTypeFilter = "*"
    )

    #Folder path to watch
    $FolderToWatch = $TargetPath
    $IncludeSubdirectories = $false
    $AttributeFilter = [IO.NotifyFilters]::FileName

    New-Item -Path "$FolderToWatch" -ItemType Directory -Force
    New-Item -Path "$LogFilePath" -ItemType File -Force

    $PSDefaultParameterValues['Write-Log:LogFilePath'] = $LogFilePath

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
            Write-Log -m "File $FileName has been created" -o "$LogFilePath"
            $FilePath = $EventDetails.FullPath
            # Format-File -FilePath $FilePath
        }

        $FileCreatedWatcher.EnableRaisingEvents = $true
        Write-Log -m "Start Watching $FolderToWatch" 

        do {
            Wait-Event -Timeout 1
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
            Write-Log -m "Handler could'nt be stopped and removed correctly." -l 1
        }

        $FileCreatedWatcher.Dispose()

        Write-Log -m "Job terminated, Cleanup is done"
    }
}