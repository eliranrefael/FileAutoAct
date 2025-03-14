#Import logging module
Import-Module -Name "$PSScriptRoot\Modules\WriteLog\WriteLog.psm1"

$PSDefaultParameterValues = @{"Write-Log:LogFilePath" = "" }

$global:JobList = New-Object System.Collections.ArrayList

<#
.SYNOPSIS
    Message data object for file manipulation job terminated event.

.DESCRIPTION
    Help to import all needed data for the job's logging and post termination clean up.
#>
class FileManipulationTerminatedEvent {
    #File's name.
    [string] $FileName

    #The terminated job.
    [System.Management.Automation.Job] $Job

    #Job's termination error message.
    [string] $TerminationError

    #The time the job took to terminate.
    [timespan] $JobDuration

    #Constructor
    FileManipulationTerminatedEvent([System.Management.Automation.Job]$job) {
        $this.Job = $job
        $this.FileName = $job.Name

        # Calculate the duration
        $this.JobDuration = New-TimeSpan -Start $job.PSBeginTime -End $job.PSEndTime

        $result = $job | Receive-Job

        # Assess job's results and update the error message if needed.
        if (($result.ExitCode -ne 0) -and ($job.ChildJobs[0].Error)) {           
            $this.TerminationError = $job.ChildJobs[0].Error          
        }
    }
}

#Creates and sets the new file created event handler on the target folder
$SetFileCreatedHandler = {

    $Init_Success_Message = "Start Watching $FolderToWatch"
    $HANDLER_CREATION_ERROR = "Error in new file created event handler. For path: $FolderToWatch. Error message:"
    try {

        $IncludeSubdirectories = $false
        $AttributeFilter = [IO.NotifyFilters]::FileName        
        #Initialize FileCreatedWatcher
        $FileCreatedWatcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
            Path                  = $script:FolderToWatch
            IncludeSubdirectories = $IncludeSubdirectories
            NotifyFilter          = $AttributeFilter
            Filter                = "*"
        }

        $FileCreatedWatcher.EnableRaisingEvents = $true

        $data = @{
            Action     = $script:Action
            FileTypeFilter = $script:FileTypeFilter
        }

        #File added event handler  

        $Handler = Register-ObjectEvent -InputObject $FileCreatedWatcher -EventName Created -MessageData $data -Action {
            
            #Sets the log file path as a parameter for Write-Log function through all the functions work.
            $MessageData = $event.MessageData
            $EventDetails = $event.SourceEventArgs
            $FilePath = $EventDetails.FullPath.Replace("'","''")
            $FileName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
            $FileExtension = [System.IO.Path]::GetExtension($FilePath).Substring(1)
            $FileTypeFilterMatch = $false
            foreach ($filter in $MessageData["FileTypeFilter"]) {

                if (($filter -eq "*") -or ($FileExtension -match $filter)) {
                    $FileTypeFilterMatch = $true
                    break
                }
            }

            if (-not $FileTypeFilterMatch) {
                return
            }
            
            $FileFullName = $EventDetails.Name
            Write-Log -m "File $FileFullName has been created"
            $ParsedAction = $($MessageData["Action"]).Replace("{FilePath}", "$FilePath").Replace("{FileName}", "$FileName").Replace("{FileExtension}", "$FileExtension")
            $FileManipulationJob = Start-job -Name "$FileFullName" -ScriptBlock {
                Invoke-Expression $using:ParsedAction
                $ExitCode = $LASTEXITCODE
                return @{ 
                    ExitCode = $exitCode
                }
            }
            $global:JobList.Add($FileManipulationJob)
        }
        Write-Log -m "$Init_Success_Message"
        return $Handler
    }
    catch {
        Write-Log -m "$HANDLER_CREATION_ERROR $_" -l 2
    }
}

#Creates and sets the file manipulation job terminated handler
$SetFileManipulationTerminatedHandler = {
    $HANDLER_CREATION_ERROR = "Error in file manipulation job terminated event handler. Error message:"

    try {
        $Handler = Register-ObjectEvent -InputObject $script:timer -EventName Elapsed -MessageData @{LogFilePath = $LogFilePath; } -Action {
                        
            $TerminatedJobs = $global:JobList.Where({ $_.State -ne 'Running' })
            if ($TerminatedJobs.Count -eq 0) {
                return
            }
            
            $LogFilePath = $event.MessageData["LogFilePath"]

            $TerminatedJobs | ForEach-Object {
                $PSDefaultParameterValues["Write-Log:LogFilePath"] = "$LogFilePath"
                $JobsData = [FileManipulationTerminatedEvent]::new($_)
                $JOB_TERMINATED_SUCCESFULLY_MEESAGE = "File manipulation on file {0} has ended succesfully. Work duration: {1}"
                $JOB_FAILED_ERROR = "File manipulation on file {0} had failed with the following error:{1}. Work duration: {2}"
                $FormattedDuration = "{0:D2}:{1:D2}:{2:D2}" -f $JobsData.JobDuration.Hours, $JobsData.JobDuration.Minutes, $JobsData.JobDuration.Seconds

                if ($null -eq $JobsData.TerminationError) {
                    Write-Log -m $($JOB_TERMINATED_SUCCESFULLY_MEESAGE -f $($JobsData.FileName), $FormattedDuration)
                }
                else {
                    Write-Log -m $($JOB_FAILED_ERROR -f $($JobsData.FileName), $($JobsData.TerminationError), $FormattedDuration) -l 2
                }
            
                #Clean up.
                $JobsData.Job | Stop-Job
                $JobsData.Job | Remove-Job
                $global:JobList.Remove($_)
            }
        }
        $script:timer.Start()
        return $Handler
    }
    catch {
        Write-Log -m "$HANDLER_CREATION_ERROR $_" -l 2
    }
}

#Stop, Remove and disponse handlers.
$RemoveHandlers = {
    param (
        [object[]]$handlers
    )

    $Error_Message = "Handler could'nt be stopped and removed correctly."
    $Success_Message = "Job terminated, Cleanup is done."

    foreach ($job in $global:JobList) {
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

    foreach ($handler in $handlers) {
        if ($handler -is [System.Management.Automation.PSEventSubscriber]) {
            try {
                Remove-Event -SourceIdentifier $handler.EventIdentifier
                $handler.Unsubscribe()
                $handler.SourceObject.Dispose()
            }        
            catch {
                Write-Log -m $Error_Message -l 1
            }
        }
    }
    Write-Log -m $Success_Message
}

<#
.SYNOPSIS
    Watch and make actions on new files.

.DESCRIPTION
    Starts watching target path for new files added and run a desired action on them.

.PARAMETER $Path
    The target path to watch on.

.PARAMETER $Act
    The action to preform on the new files, 
    must conatin the substring {FilePath} where the files path should be placed,
    can also contain the substings {FileName} or {FileExtension}, where the file name or file extention should be placed.

.PARAMETER $LogFilePath
    Log file path (Default is .\logoutput.txt).

.PARAMETER $Filter
    Filter for specific file types to watch for (Default is all).

.EXAMPLE
    Watch-File -p "C:\test\" -l "C:\logoutput.txt" -a "Rename-Item -Path '{FilePath}' -NewName 'manipulated-{FileName}' -f 'txt','pdf'"
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
        #Log file path.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("l")]
        [string]$LogFilePath = ".\logoutput.txt",
        #Log file path.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("f")]
        [string[]]$Filter = @('*')
    )
    $script:FolderToWatch = $Path
    $script:Action = $Act
    $script:FileTypeFilter = $Filter
    $PSDefaultParameterValues["Write-Log:LogFilePath"] = "$LogFilePath"

    #Sets the log file path as a parameter for Write-Log function through all the functions work.
    # $global:PSDefaultParameterValues['Write-Log:LogFilePath'] = $script:LogFilePath

    try {

        $FileAddedHandler = & $script:SetFileCreatedHandler

        $script:timer = New-Object Timers.Timer
        $script:timer.Interval = 5000
        $script:timer.AutoReset = $true
    
        $FileManipulationTerminatedHandler = & $script:SetFileManipulationTerminatedHandler

        do {
            Start-Sleep -Seconds 1
        }while ($true)
    }
    catch [System.Exception] {
        Write-Log -m "$_" -l 2
    }
    finally {
        & $script:RemoveHandlers -handlers @($FileAddedHandler, $FileManipulationTerminatedHandler)
    }
}
