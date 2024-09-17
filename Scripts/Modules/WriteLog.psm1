<#
.SYNOPSIS
    This is a custom logging module
.DESCRIPTION
    This module use preconfigured visual settings for prompting user friendly messages and adding them to preconfigures or given log file.
.Notes
    Auther: Eliran Refael
    Date: 15/9/2024
#>


<#
.SYNOPSIS
    Log types titles.

.DESCRIPTION
    Available log types, represent the severty or the type of event that triggered the message.
#>
enum LogType {
    Info
    Warning
    Error
}

<#
.SYNOPSIS
   Colors allowed for display.

.DESCRIPTION
    Available colors allowed to use in the message to host response.
#>
enum LogColor {
    Black
    Green
    Red
    Yellow
}

<#
.SYNOPSIS
    Log type settings for display and outsource.

.DESCRIPTION
    Class with log type name, desired text color and background color for display, and a function for getting the color settings as a hashtable for write-host command.

.EXAMPLE
    #Constructor
        [LogTypeSettings]::new([LogType]::Info, [LogColor]::Green, [LogColor]::Yellow)

    #Using color settings in write-host
        Write-Host "example" $logTypeSettingsExample.GetColorsHash()
#>
class LogTypeSettings {
    #The name of the the log type.
    [LogType]$Name
    #The color of the log's text for host.
    [LogColor]$TextColor
    #The background color of the log's text for host.
    [LogColor]$BackgroundColor

    #Constructor
    LogTypeSettings([LogType]$name, [LogColor]$textColor, [LogColor]$backgroundColor) {
        $this.Name = $name
        $this.TextColor = $textColor
        $this.BackgroundColor = $backgroundColor
    }

    #Return the color settings as hash table for usage in commands that take foregroundcolor and background color as arguments
    [hashtable]GetColorsHash() {
        return @{
            ForegroundColor = $this.TextColor.toString()
            BackgroundColor = $this.BackgroundColor.toString()
        }
    }
}


<#
.SYNOPSIS
    Writes custom logs designed by log level to host and log file.
.DESCRIPTION
    Gets the message input, log level, and output file path. prompt a colorful message to the host, and append the log to the log file.
.PARAMETER LogMessage
    Message to log.
.PARAMETER LogLevel
    Log level -> 0=Info, 1=Warning, 2=Error.
.PARAMETER LogFilePath
    Log file path.
.EXAMPLE
   Example of how to use the function or script.
#>
function Write-Log {
    Param (
        #Message for display
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias("m")]
        [string]$LogMessage,
        #Log level -> 0=Info 1=Warning 2=Error
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(0, 2)]
        [Alias("l")]
        [int]$LogLevel = 0,
        #Path of the log file for logging output
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias("o")]
        [string]$LogFilePath
    )

    if (-not $(Test-Path "$LogFilePath" -PathType Leaf)) {
        New-Item -Path "$LogFilePath" -ItemType File -Force
    }

    $ERROR_TYPE_INDEX = -1
    $FILE_PATH_NOT_FOUND_MESSAGE = "Log file path couldnt be found"
    $FILE_PATH_NOT_VALID_MESSAGE = "Log file path isnt valid"

    $LogTypesList = @(
        [LogTypeSettings]::new([LogType]::Info, [LogColor]::Green, [LogColor]::Yellow)
        [LogTypeSettings]::new([LogType]::Warning, [LogColor]::Yellow, [LogColor]::Black)
        [LogTypeSettings]::new([LogType]::Error, [LogColor]::Black, [LogColor]::Red)
    )
    $currentLogtype = $LogTypesList[$LogLevel]
    $errorLogSettings = $LogTypesList[$ERROR_TYPE_INDEX]
    $errorColorHash = $errorLogSettings.GetColorsHash()

    if ($PSBoundParameters.ContainsKey('LogFilePath')) {
        $currentLogFilePath = $LogFilePath
    }
    else {
        if ($global:LogFilePath -eq $null) {
            Write-Host $FILE_PATH_NOT_FOUND_MESSAGE @errorColorHash
            return
        }
        $currentLogFilePath = $global:LogFilePath
    }

    if (-not $(Test-Path -Path $currentLogFilePath -IsValid)) {
        Write-Host $FILE_PATH_NOT_VALID_MESSAGE @errorColorHash
        return
    }

    $logColorsHash = $currentLogtype.GetColorsHash()
    Write-Host "$LogMessage" @logColorsHash
    Add-Content -Path $currentLogFilePath -Value "$($currentLogtype.Name) - $(Get-Date) - $LogMessage"
    return
} 