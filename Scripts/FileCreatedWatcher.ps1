#Import logging module
Import-Module -Name "$PSScriptRoot\Modules\WriteLog\WriteLog.psm1"

<#
.SYNOPSIS
    Message data object for file manipulation job terminated event.

.DESCRIPTION
    Help to import all needed data for the job's logging and post termination clean up.
#>
class FileManipulationTerminatedEvent {
    #Events name.
    [string] $EventName = "FileManipulationTerminated"

    #File's name.
    [string] $FileName

    #Log file's path.
    [string] $LogFilePath

    #The terminated job.
    [System.Management.Automation.Job] $Job

    #Job's termination error message.
    [string] $TerminationError

    #The time the job took to terminate.
    [timespan] $JobDuration

    #Constructor
    FileManipulationTerminatedEvent([System.Management.Automation.Job]$job, [string]$fileName, [string]$logFilePath) {
        $this.Job = $job
        $this.FileName = $fileName
        $this.LogFilePath = $logFilePath

        # Calculate the duration
        $durationSeconds = ($job.EndTime - $job.StartTime).TotalSeconds
        $this.JobDuration = [TimeSpan]::FromSeconds($durationSeconds)

        # Assess job's results and update the error message if needed.
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
        [Alias("p")]
        [string]$TargetPath,
        #action to perform on new files.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern(".+({FilePath}).*")]
        [Alias("a")]
        [string]$Action,
        #Timeout per manipulation
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("t")]
        [int]$Timeout = 3600,
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

        #File added event handler  
        $FileAddedHandler = Register-ObjectEvent -InputObject $FileCreatedWatcher -EventName Created -MessageData @{LogFilePath = $LogFilePath; FileAction = $Action; FileActionTimeout = $Timeout } -Action {
            $EventDetails = $event.SourceEventArgs
            $FileName = $EventDetails.Name
            $FilePath = $EventDetails.FullPath
            $MessageData = $event.MessageData
            try {
                Write-Log -m "File $FileName has been created" -o "$($MessageData["LogFilePath"])"
                $ParsedAction = $($MessageData["FileAction"]).Replace("{FilePath}", "$FilePath").Replace("{FileName}", "$FileName")
                $FileManipulationJob = Start-job -ScriptBlock {
                    param($action)
                    Invoke-Expression $action
                } -ArgumentList $ParsedAction
    
                Wait-Job -Job $FileManipulationJob -Timeout $($MessageData["FileActionTimeout"])
                $CustomJobResultsEvent = [FileManipulationTerminatedEvent]::new($FileManipulationJob, $FileName)
                New-Event -SourceIdentifier "$($CustomJobResultsEvent.EventName)" -MessageData @{LogFilePath = $MessageData["LogFilePath"]; JobsData = $CustomJobResultsEvent }
            }
            catch {
                Write-Verbose "An error occurred in the event handler: $_"
            }
        }

        #File manipulation terminated event handler
        $FileManipulationTerminatedHandler = Register-EngineEvent -SourceIdentifier "FileManipulationTerminated" -Action {
            $EventsArgs = $event.SourceEventArgs
            $MessageData = $event.MessageData
            $JobsData = $MessageData["JobsData"]
            $FormattedDuration = "{0:D2}{1:D2}{2:D2}" -f $JobsData.JobDuration.Hours, $JobsData.JobDuration.Minutes, $JobsData.JobDuration.Seconds
            try {
                if ($null -eq $JobsData.TerminationError) {
                    Write-log "File manipulation on file $($JobsData.FileName) has ended succesfully. Work duration: $FormattedDuration" -o "$($MessageData["LogFilePath"])"
                }
                else {
                    Write-log "File manipulation on file $($JobsData.FileName) had failed with the following error:$($JobsData.TerminationError). Work duration: $FormattedDuration" -l 2 -o "$($MessageData["LogFilePath"])"
                }
        
                $EventsArgs.Job | Stop-Job
                $EventsArgs.Job | Remove-Job
            }
            catch {
                Write-Verbose "An error occurred in the event handler: $_"
            }
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
            if ($FileAddedHandler -is [System.Management.Automation.Job]) {
                $FileAddedHandler | Stop-Job
                $FileAddedHandler | Remove-Job
            }

            if ($FileManipulationTerminatedHandler -is [System.Management.Automation.Job]) {
                $FileManipulationTerminatedHandler | Stop-Job
                $FileManipulationTerminatedHandler | Remove-Job 
            }
        }
        catch {
            Write-Log -m "Handler could'nt be stopped and removed correctly." -l 1
        }

        $FileCreatedWatcher.Dispose()

        Write-Log -m "Job terminated, Cleanup is done"
    }
}