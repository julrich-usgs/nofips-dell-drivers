# DellUpdateFunctions.ps1
#
#   Required module for nofips-dell-drivers. Does nothing by itself.
#
# Shared Variables:
$downloadLocation = $PSScriptRoot + "\DellDrivers\"
$processlog = $downloadLocation + "process.log"
$installScript = $downloadLocation + "install.ps1"
$xmlcatalog = $downloadLocation + "driverUpdates.xml"
$dcucli = $PSScriptRoot + "\dcu-cli.exe"
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 


# Writes a message to the console, a file, and the GUI!
Function LogNote([string] $message){
    Write-Host $message
    Add-Content $processlog $message
    if ($global:gui){
        $Note.Text = $message
    }
}

# Runs Dell Command Update and makes XML report of available updates
Function CheckForUpdates() {
    # Initialize the update location
    mkdir -Path $downloadLocation -Force
    New-Item -ItemType "file" -Path $processlog -Force
    New-Item -ItemType "file" -Path $xmlcatalog -Force

    # Required to pass local variables to background job
    $scriptBlok = {
        param ($dcucli, $xmlcatalog)
        Start-Process -Wait -FilePath $dcucli -ArgumentList "/report $xmlcatalog" -WindowStyle hidden
    }

    # Check for update as a background job
    Start-Job -ScriptBlock $scriptBlok -ArgumentList $dcucli, $xmlcatalog
    LogNote "Checking System for Updates. Please wait... "

    SpinWait
    LogNote "Dell Command Update Client Finished"
}

# Downloads all the update files and makes the Installation Script, takes an arraylist of String
Function DownloadUpdates($urlist){
    New-Item -ItemType "file" -Path $installScript -Force

    ForEach($url in $urlist) {
        $downloadFile = $url -Split "/"
        $downloadFile = $downloadFile[$downloadFile.length - 1]
        $filePath = $downloadLocation + $downloadFile
        LogNote "Attempting download $url"

        # Download as a background job
        Start-Job -ScriptBlock ${function:DownloadWithRetry} -ArgumentList $url, $filePath, 5

        # Add command to install script
        Add-Content $installScript "Start-Process -Wait -FilePath `"$filePath`" -ArgumentList `"/s`", `"/l=```"$filePath.log```"`""
    }

    SpinWait
}

# Download the file specified by url to the out file location, can retry
function DownloadWithRetry([string] $url, [string] $outFile, [int] $retries)
{
    while($true)
    {
        try
        {
            Invoke-WebRequest $url -OutFile $outFile -UseBasicParsing
            Write-Verbose "Download succeeded"
            break
        }
        catch
        {
            $exceptionMessage = $_.Exception.Message
            Write-Verbose "Failed to download '$url': $exceptionMessage"
            if ($retries -gt 0) {
                $retries--
                Write-Verbose "Waiting 10 seconds before retrying. Retries left: $retries"
                Start-Sleep -Seconds 10
            }
            else
            {
                Write-Verbose "Max retries reached download failed $url"
                throw $_.Exception
            }
        }
    }
}

# Runs the install script as background job
Function InstallUpdates(){
    Start-Job -FilePath $installScript
    Write-Host | Get-Content $installScript
    LogNote "Installing updates... "
    SpinWait
    LogNote "Installation Finished! Reboot may be required."
}

# SpinWait prevents GUI lockup due to running Powershell commands on a WinForms thread
function SpinWait() {
    [System.Windows.Forms.Application]::UseWaitCursor=$true
    if ($global:gui){$oldNote = $Note.Text}
    $spinner = ".oO@+-\|/-"

    While (@(Get-Job | Where-Object { $_.State -eq "Running" }).Count -ne 0)
    {
        Start-Sleep -Milliseconds 222
        if ($global:gui){ 
            $Note.Text = $oldNote + $spinner.Substring($spinStep, 1)
            $spinStep++
            if ($spinStep -gt $spinner.Length - 1) {$spinStep = 0}
        }

        # TODO: Replace DoEvents with an async await Receive-Job (I couldn't find a way to do this)
        [System.Windows.Forms.Application]::DoEvents()
    }

    # Clean up jobs
    Remove-Job -State Completed
    Remove-Job -State Failed
    [System.Windows.Forms.Application]::UseWaitCursor=$false
}
