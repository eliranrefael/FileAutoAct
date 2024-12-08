Import-Module Pester

Describe "Creating New File" {
    BeforeAll {
        $CapturedOutput = @("")
        $testDrive = Get-PSDrive -Name "TestDrive"
        $WatchedFolderPath = "$($testDrive.Root)"
        New-Item -Path "$WatchedFolderPath\log" -ItemType Directory -Force
        $LogFilePath = "$WatchedFolderPath\log\logoutput.txt"
        $Action = "Rename-Item -Path '{FilePath}' -NewName 'manipulated-{FileName}.{FileExtension}'"
        $FileCreatorWatcherPath = "$([System.IO.Directory]::GetParent($PSScriptRoot).FullName)\Scripts\FileCreatedWatcher.ps1"

        $job = Start-Job -ScriptBlock {
            param($folderPath, $logFilePath, $fileCreatorWatcherPath, $action)
            . $fileCreatorWatcherPath
            Watch-File -p $folderPath -l $logFilePath -a $action
        } -ArgumentList @($WatchedFolderPath, $LogFilePath, $FileCreatorWatcherPath, $Action)
        Start-Sleep -Seconds 3
    }

    Context "qualified new file has created" {
        BeforeAll {
            $TestFileName = "file.txt"
            New-Item -Path "$WatchedFolderPath\$TestFileName" -ItemType File -Force
            Start-Sleep -Seconds 6
            if (Test-Path -Path $LogFilePath) {
                $CapturedOutput = Get-Content -Path $LogFilePath
            }

            $script:lineIndex = 0
        }

        It "should start with a start watching message" {
            $EXPECTED_MESSAGE = "*Start Watching $WatchedFolderPath"
            $CapturedOutput[$script:lineIndex] -like $EXPECTED_MESSAGE | Should -BeTrue
        }
    
        It "should catch the file created event and respond with a message" {
            $EXPECTED_MESSAGE = "*File $TestFileName has been created"
            $CapturedOutput[$script:lineIndex] -like $EXPECTED_MESSAGE | Should -BeTrue
        }
    
        It "should perform the manipulation on file and inform host with a message" {
            $EXPECTED_MESSAGE = "*File manipulation on file $TestFileName has ended succesfully.*"
            ($CapturedOutput[$script:lineIndex] -like $EXPECTED_MESSAGE) -and (Test-Path "$WatchedFolderPath\manipulated-$TestFileName" -PathType Leaf)  | Should -BeTrue
        }
    }

    Context "stopped successfully" {
        BeforeAll {
            Stop-Job -Job $job
            if (Test-Path -Path $LogFilePath) {
                $CapturedOutput = Get-Content -Path $LogFilePath
            }
        }

        It "should end with a termination message" {
            $EXPECTED_MESSAGE = "*Job terminated, Cleanup is done.*"
            $CapturedOutput[$script:lineIndex] -like $EXPECTED_MESSAGE | Should -BeTrue
        }
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

    AfterEach {
        $script:lineIndex += 1
    }

    AfterAll {
        $output = Receive-Job -Job $job -Wait -AutoRemoveJob
        Write-Host $output
    }
}
