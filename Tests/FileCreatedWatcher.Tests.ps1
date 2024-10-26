Import-Module Pester

Describe "FileCreatedWatcher Tests" {
    $CapturedOutput = @()
    BeforeAll {       
        $WatchedFolderPath = "$PSScriptRoot\test"
        $LogFilePath = "$PSScriptRoot\log\logoutput.txt"
        $Action = "Rename-Item -Path '{FilePath}' -NewName 'manipulated-{FileName}.{FileExtension}'"
        $FileCreatorWatcherPath = "$([System.IO.Directory]::GetParent($PSScriptRoot).FullName)\Scripts\FileCreatedWatcher.ps1"
        New-Item -Path "$WatchedFolderPath" -ItemType Directory -Force
        Remove-Item -Path "$WatchedFolderPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$LogFilePath" -Force -ErrorAction SilentlyContinue

        $job = Start-Job -ScriptBlock {
            param($folderPath, $logFilePath, $fileCreatorWatcherPath, $action)
            . $fileCreatorWatcherPath
            Watch-File -p $folderPath -l $logFilePath -a $action
        } -ArgumentList @($WatchedFolderPath, $LogFilePath, $FileCreatorWatcherPath, $Action)
        Start-Sleep -Seconds 3
        $TestFileName = "file.txt"
        New-Item -Path "$WatchedFolderPath\$TestFileName" -ItemType File -Force
        Start-Sleep -Seconds 6
        Stop-Job -Job $job
        Remove-Job -Job $job
        $CapturedOutput = Get-Content -Path $LogFilePath
    }

    It "should start with a start watching message" {
        $EXPECTED_MESSAGE = "*Start Watching $WatchedFolderPath"
        $CapturedOutput[0] -like $EXPECTED_MESSAGE | Should -BeTrue
    }

    It "should catch the file created event and respond with a message" {
        $EXPECTED_MESSAGE = "*File $TestFileName has been created"
        $CapturedOutput[1] -like $EXPECTED_MESSAGE | Should -BeTrue
    }

    It "should perform the manipulation on file and inform host with a message" {
        $EXPECTED_MESSAGE = "*File manipulation on file $TestFileName has ended succesfully.*"
        ($CapturedOutput[2] -like $EXPECTED_MESSAGE) -and (Test-Path "$WatchedFolderPath\manipulated-$TestFileName" -PathType Leaf)  | Should -BeTrue
    }

    It "should end with a termination message" {
        $EXPECTED_MESSAGE = "*Job terminated, Cleanup is done*"
        $CapturedOutput[-1] -like $EXPECTED_MESSAGE | Should -BeTrue
    }
    
    # It "should respond to file creation event and run specific commands" {
    
    #     # Call the function that uses FileSystemWatcher
    #     Start-FileWatcher -Path "C:\test\path"
    
    #     # Simulate the file event
    #     $action = {
    #         param ($source, $eventArgs)
    #         Write-Host "File event detected: $($eventArgs.FullPath)"
    #         Write-Host "Running specific command..."
    #     }
    #     $action.Invoke($null, $mockEventArgs)
    
    #     # Check the captured output
    #     $global:CapturedOutput | Should -Contain "File event detected: C:\test\path\file.txt"
    #     $global:CapturedOutput | Should -Contain "Running specific command..."
    # }
    
    # It "should handle Ctrl+C and cleanup properly" {
    #     # Simulate Ctrl+C interrupt
    #     try {
    #         # Simulate Ctrl+C interrupt
    #         throw [System.Management.Automation.Host.HostCallFailedException]
    #     }
    #     catch [System.Management.Automation.Host.HostCallFailedException] {
    #         Write-Host "Goodbye!"
    #     }
    #     finally {
    #         # Ensure cleanup actions are performed if implemented
    #         # Example of cleanup check, if any
    #     }
    
    #     # Check for goodbye message
    #     $global:CapturedOutput | Should -Contain "Goodbye!"
    # }
    # AfterAll {
    # }
    AfterAll {
    }
}
