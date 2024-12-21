# :file_folder::arrows_counterclockwise::card_index_dividers:		FileAutoAct

 ## :open_book:	 Table Of Content
1. [About](#-About)
   - [Motivation](#-Motivation)
   - [The General Idea](#-The-General-Idea)
3. [Development](#-Development)
   - [Structure And Technology](#-Structure-And-Technology)
   - [Current Development](#-Current-Development)
   - [Future Goals](#-Future-Goals)
5. [Usage](#-Usage)
   - [Downloading](#-Downloading)
   - [Example](#-Example)
   - [Tests](#-Tests)
7. [Contribution](#-Contribution)

 ## About

 ### :thinking:	Motivation
As someone who loves storing media on both physical hard drives and cloud services,
I’ve noticed that media files are getting heavier over time.

This increase is driven by advancements in technology and capture quality, alongside a lack of consistent standards in compression and efficiency of data.

Consequently, it’s becoming increasingly difficult to store all the media I wish to cherish on the drives I own.


### :frog: The Problem
After some digging, I discovered quality and compression standards that can satisfy my expectations while achieving an impressive reduction of up to 85% in file size.

This can be accomplished using powerful tools like **[HandbrakeCLI](https://github.com/HandBrake/HandBrake)** and **[FFmpeg
](https://github.com/FFmpeg/FFmpeg)**.

Unfortunately, as a Windows user, I haven’t found a convenient, lightweight way to automate this file conversion process from the moment files are downloaded to their target folders.
  

### :bulb: The General Idea
Since all my desired actions on files are accessible via the command line, and my current need is for a lightweight, Windows-friendly solution, I saw that as a wonderful opportunity to practice some PowerShell coding. and indeed, I found it to be quite satisfying.

The idea is to create a PowerShell program that loads at startup with predefined configurations of actions and parameters. By leveraging Windows native OI events, it can efficiently perform the desired actions on files in the background, parallelizing tasks while maintaining a balanced load.

 
 ## Development
 
 ### :paperclips:	Structure And Technology
 Programming Language: PowerShell v7
 Testing Framework: Pester v5.6.1
 Git Submodules: **[WriteLog](https://gist.github.com/eliranrefael/33bd61aa849b84ea78495c2d37d7706d)**[^1]
 
> [!IMPORTANT]
> When cloning please don't forget to clone the submodules too:
> `git clone --recurse-submodules https://github.com/eliranrefael/FileAutoAct.git`
 

### :hammer_and_wrench: Current Development
An initial **[alpha version](https://github.com/eliranrefael/FileAutoAct/tree/v1.0.0-alpha)** is available. This version has been successfully tested for monitoring new files in the target folder and performing actions on them.

The current goal is to develop more tests that will ensure stability, reliability, and concurrency while performing more resource-consuming actions on the new files.

**Task List**
- [x] Multiple file extensions filter
- [ ] Create more extreme scenarios tests
- [ ] Create a user interface using shell dialog script for initiating, preconfigurations, and start on startup option
- [ ] improve process's progress and monitoring view.

 
 ### :bow_and_arrow: Future Goals
 Consider creating a simple user-friendly GUI control panel for FileAutoAct jobs definition and management.
 
 
 ## Usage
 
 ### :arrow_heading_down:	Downloading
 > [!WARNING]
 > Git's download option doesn't automatically include the project's git submodules, therefor the program won't run.
 > Until a zip file is available, downloading can only be done by [cloning](-#Structure-And-Technology) the repo.

 
 ### :tipping_hand_man:	Example
 1. Open a PowerShell window where the files are downloaded to.
 2. type `. .\Scripts\FileCreatedWatcher.ps1` to import the main function to the session.
 3. call the function, `Watch-File -p '{Target folder for watching}' -l '{Log file path}' -a "Rename-Item -Path '{FilePath}' -NewName 'manipulated-{FileName}'" -f "txt","pdf","mp3"`

 > [!NOTE]
 > - Watched directory path and desired action are the only mandatory parameters.

 
 ### :rabbit2: Tests
 Run `Invoke-Pester -Path .\Tests\FileCreatedWatcher.Tests.ps1`

 > [!TIP]
 > - Make sure Pester modules are [installed](https://pester.dev/docs/introduction/installation) on your system.
 
 
 ## :mage_man: Contribution
Please feel more than free to comment, ask, and come up with new ideas and suggestions in the [Discussion](https://github.com/eliranrefael/FileAutoAct/discussions) and [Issues](https://github.com/eliranrefael/FileAutoAct/issues) section.
As mentioned earlier, this is my first PowerShell project, and I would greatly appreciate any feedback you may have on my work. :cupid:.



[^1]: Used for logging to a dedicated log file and to the host, mainly used for testing.
