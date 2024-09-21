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
    FileManipulationTerminatedEvent([System.Management.Automation.Job]$job, [string]$fileName) {
        $this.Job = $job
        $this.FileName = $fileName
        $this.LogFilePath = $global:logFilePath

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


<#
.SYNOPSIS
    Initiate watch and .

.DESCRIPTION
    Starts watching target folder for new files and manage desired manipulations on them.

.PARAMETER $FolderToWatch
    The target folder to watch for new files.
.PARAMETER $Action
    The command line to preform on the new files, 
    must conatin the substring {FilePath} in the location of the file's path,
    can also conatin the substing {FileName} if necessary.
.PARAMETER $Timeout
    Timeout for action process time.
.PARAMETER $LogFilePath
    Log file path (Default is .\logoutput.txt).
.PARAMETER $FileTypeFilter
    Filter for specific file types to watch for (Default is all).
.EXAMPLE
    Watch-File -p "C:\test\" -l "C:\logoutput.txt" -a "Rename-Item -Path '{FilePath}' -NewName 'manipulated-{FileName}'"
#>
function Watch-File() {
    Param (
        #Path to watch for new files.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [Alias("p")]
        [string]$Path,
        #action to perform on new files.
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern(".+({FilePath}).*")]
        [Alias("a")]
        [string]$Act,
        #Timeout per manipulation
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("t")]
        [int]$Timeout = 3600,
        #Log file path.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("l")]
        [string]$LogPath = ".\logoutput.txt",
        #Log file path.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("f")]
        [string]$Filter = "*"
    )

    $script:FolderToWatch = $Path
    $script:Action = $Act
    $script:FileTypeFilter = $Filter
    $script:TimeoutSeconds = $Timeout 
    $global:LogFilePath = $LogPath


    New-Item -Path "$LogFilePath" -ItemType File -Force

    #Sets the log file path as a parameter for Write-Log function through all the functions work.
    # $global:PSDefaultParameterValues['Write-Log:LogFilePath'] = $script:LogFilePath

    try {

        $FileAddedHandler = & $script:SetFileCreatedHandler

        $FileManipulationTerminatedHandler = & $script:SetFileManipulationTerminatedHandler

        do {
            Wait-Event -Timeout 1
        }while ($true)
    }
    finally {
        & $script:RemoveHandlers -jobs @($FileAddedHandler, $FileManipulationTerminatedHandler)
    }
}

#Creates and sets the new file created event handler on the target folder
$script:SetFileCreatedHandler = {

    $Init_Success_Message = "Start Watching $script:FolderToWatch"
    $HANDLER_CREATION_ERROR = "Error in new file created event handler. Error message:"
    try {

        $IncludeSubdirectories = $false
        $AttributeFilter = [IO.NotifyFilters]::FileName        
        #Initialize FileCreatedWatcher
        $FileCreatedWatcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
            Path                  = $script:FolderToWatch
            Filter                = $script:FileTypeFilter
            IncludeSubdirectories = $IncludeSubdirectories
            NotifyFilter          = $AttributeFilter
            EnableRaisingEvents   = $true
        }

        #File added event handler  
        $Handler = Register-ObjectEvent -InputObject $FileCreatedWatcher -EventName Created -MessageData @{LogFilePath = $global:LogFilePath; FileAction = $script:Action; FileActionTimeout = $script:TimeoutSeconds } -Action {
            #Sets the log file path as a parameter for Write-Log function through all the functions work.
            $EventDetails = $event.SourceEventArgs
            $FileName = $EventDetails.Name
            $FilePath = $EventDetails.FullPath
            $MessageData = $event.MessageData
            Write-Log -m "File $FileName has been created"
            $ParsedAction = $($MessageData["FileAction"]).Replace("{FilePath}", "$FilePath").Replace("{FileName}", "$FileName")
            $FileManipulationJob = Start-job -ScriptBlock {
                param($action)
                Invoke-Expression $action
            } -ArgumentList $ParsedAction

            Wait-Job -Job $FileManipulationJob -Timeout $($MessageData["FileActionTimeout"])
            $CustomJobResultsEvent = [FileManipulationTerminatedEvent]::new($FileManipulationJob, $FileName)
            New-Event -SourceIdentifier "$($CustomJobResultsEvent.EventName)" -MessageData @{LogFilePath = $MessageData["LogFilePath"]; JobsData = $CustomJobResultsEvent }
        }
        Write-Log -m "$Init_Success_Message"
        return $Handler
    }
    catch {
        Write-Log -m "$HANDLER_CREATION_ERROR $_" -l 2
    }
}

#Creates and sets the file manipulation job terminated handler
$script:SetFileManipulationTerminatedHandler = {
    $EVENT_NAME = "FileManipulationTerminated"
    $HANDLER_CREATION_ERROR = "Error in file manipulation job terminated event handler. Error message:"

    try {
        $Handler = Register-EngineEvent -SourceIdentifier $EVENT_NAME -Action {
            $JOB_TERMINATED_SUCCESFULLY_MEESAGE = "File manipulation on file {0} has ended succesfully. Work duration: {1}"
            $JOB_FAILED_ERROR = "File manipulation on file {0} had failed with the following error:{1}. Work duration: {2}"
            $LogFilePath = $MessageData["LogFilePath"]
            $MessageData = $event.MessageData
            $JobsData = $MessageData["JobsData"]
            $FormattedDuration = "{0:D2}{1:D2}{2:D2}" -f $JobsData.JobDuration.Hours, $JobsData.JobDuration.Minutes, $JobsData.JobDuration.Seconds

            if ($null -eq $JobsData.TerminationError) {
                Write-Log -m $($JOB_TERMINATED_SUCCESFULLY_MEESAGE -f $($JobsData.FileName), $FormattedDuration)
            }
            else {
                Write-Log -m $($JOB_FAILED_ERROR -f $($JobsData.FileName), $($JobsData.TerminationError), $FormattedDuration) -l 2
            }
            
            #Clean up.
            $JobsData.Job | Stop-Job
            $JobsData.Job | Remove-Job
        }
        return $Handler
    }
    catch {
        Write-Log -m "$HANDLER_CREATION_ERROR $_" -l 2
    }
}

#Stop, Remove and disponse handlers.
$script:RemoveHandlers = {
    param (
        [object[]]$jobs
    )

    $Error_Message = "Handler could'nt be stopped and removed correctly."
    $Success_Message = "Job terminated, Cleanup is done."

    foreach ($job in $jobs) {
        if ($job -is [System.Management.Automation.Job]) {
            try {
                $job | Stop-Job
                $job | Remove-Job
                $job.Dispose()
            }        
            catch {
                Write-Log -m $Error_Message -l 1
            }
        }
    }
    Write-Log -m $Success_Message
}