Import-Module Pester

Describe "Creating New File" {
    BeforeAll {
        $script:CapturedOutput = @("")
        $script:LastCapturedOutput = ""
        $testDrive = Get-PSDrive -Name "TestDrive"
        $WatchedFolderPath = "$($testDrive.Root)"
        New-Item -Path "$WatchedFolderPath\log" -ItemType Directory -Force
        $LogFilePath = "$WatchedFolderPath\log\logoutput.txt"
        $Action = "Rename-Item -Path '{FilePath}' -NewName 'manipulated-{FileName}.{FileExtension}'"
        $FileTypeFilter = "txt"
        $FileCreatorWatcherPath = "$([System.IO.Directory]::GetParent($PSScriptRoot).FullName)\Scripts\FileCreatedWatcher.ps1"

        $job = Start-ThreadJob -ScriptBlock {
            param($folderPath, $logFilePath, $fileCreatorWatcherPath, $action, $fileTypeFilter)
            . $fileCreatorWatcherPath
            Watch-File -p $folderPath -l $logFilePath -a $action -f $fileTypeFilter
        } -ArgumentList @($WatchedFolderPath, $LogFilePath, $FileCreatorWatcherPath, $Action, $FileTypeFilter)
        Start-Sleep -Seconds 3
    }

    Context "qualified new file has created" {
        BeforeAll {
            $TestFileName = "file.txt"
            New-Item -Path "$WatchedFolderPath\$TestFileName" -ItemType File -Force
            Start-Sleep -Seconds 6
            if (Test-Path -Path $LogFilePath) {
                $script:CapturedOutput = Get-Content -Path $LogFilePath
            }

            $script:lineIndex = 0
        }

        It "should start with a start watching message" {
            $EXPECTED_MESSAGE = "*Start Watching $WatchedFolderPath"
            $script:LastCapturedOutput -like $EXPECTED_MESSAGE | Should -BeTrue
        }
    
        It "should catch the file created event and respond with a message" {
            $EXPECTED_MESSAGE = "*File $TestFileName has been created"
            $script:LastCapturedOutput -like $EXPECTED_MESSAGE | Should -BeTrue
        }
    
        It "should perform the manipulation on file and inform host with a message" {
            $EXPECTED_MESSAGE = "*File manipulation on file $TestFileName has ended succesfully.*"
            ($script:LastCapturedOutput -like $EXPECTED_MESSAGE) -and (Test-Path "$WatchedFolderPath\manipulated-$TestFileName" -PathType Leaf)  | Should -BeTrue
        }
    }

    Context "unqualified new file has created" {
        BeforeAll {
            $TestFileName = "file.mp3"
            New-Item -Path "$WatchedFolderPath\$TestFileName" -ItemType File -Force
            Start-Sleep -Seconds 6
            if (Test-Path -Path $LogFilePath) {
                $script:CapturedOutput = Get-Content -Path $LogFilePath
            }
        }
        It "Should'nt react with the new file" {
            $script:LastCapturedOutput | Should -BeNullOrEmpty
            $script:lineIndex -= 1
            (Test-Path "$WatchedFolderPath\$TestFileName" -PathType Leaf) | Should -BeTrue
        }
    }

    Context "stopped successfully" {
        BeforeAll {
            Stop-Job -Job $job
            if (Test-Path -Path $LogFilePath) {
                $script:CapturedOutput = Get-Content -Path $LogFilePath
            }
        }

        It "should end with a termination message" -Tag "Last" {
            $EXPECTED_MESSAGE = "*Job terminated, Cleanup is done.*"
            $script:LastCapturedOutput -like $EXPECTED_MESSAGE | Should -BeTrue
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

    BeforeEach {
        if ($script:CapturedOutput -is [string]) {
            $script:LastCapturedOutput = $script:CapturedOutput
        }
        elseif ($script:CapturedOutput -is [array]) {
            if ($____Pester.CurrentTest.Tag -contains "Last") {
                $script:LastCapturedOutput = $script:CapturedOutput[-1]

            }
            else {
                $script:LastCapturedOutput = $script:CapturedOutput[$script:lineIndex]
            }
        }
    }

    AfterEach {
        $script:lineIndex += 1
    }

    AfterAll {
        $output = Receive-Job -Job $job -Wait -AutoRemoveJob
        Write-Host $output
    }
}
