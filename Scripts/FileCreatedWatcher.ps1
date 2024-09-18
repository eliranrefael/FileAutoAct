Import-Module -Name "$PSScriptRoot\Modules\FormatFile.psm1"
Import-Module -Name "$PSScriptRoot\Modules\WriteLog\WriteLog.psm1"

#can it be simplified by implementing component class? https://learn.microsoft.com/en-us/dotnet/api/system.componentmodel.component?view=net-8.0
class FileManipulationTerminatedEvent {
    #Events name
    [string] $EventName = "FileManipulationTerminated"

    #File's name
    [string] $FileName

    #The terminated job
    [System.Management.Automation.Job]$Job

    #Termination Error
    [string]$TerminationError

    #The time the job took to terminate.
    [timespan]$JobDuration

    #Constructor
    FileManipulationTerminatedEvent([System.Management.Automation.Job]$job, [string]$fileName) {
        $this.Job = $job
        $this.FileName = $fileName

        # Calculate the duration
        $durationSeconds = ($job.EndTime - $job.StartTime).TotalSeconds
        $this.JobDuration = [TimeSpan]::FromSeconds($durationSeconds)
        $jobsResults = Receive-Job -Job $job -ErrorAction Stop
        if ($jobsResults -is [System.Management.Automation.ErrorRecord]) {
            $this.TerminationError = $jobsResults.Exception.Message
        }
        elseif ($job.State -eq 'Failed') {
            $this.TerminationError = $jobsResults
        }
    }
}

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