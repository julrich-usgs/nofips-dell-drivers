# DellUpdateFunctions.ps1
#
# Define Shared Variables:
$downloadLocation = $PSScriptRoot + "\DellDrivers\"
$processlog = $downloadLocation + "process.log"
$installScript = $downloadLocation + "install.ps1"
$xmlcatalog = $downloadLocation + "driverUpdates.xml"
$dcucli = $PSScriptRoot + "\dcu-cli.exe"



# Writes a message to the console, a file, and the GUI!
Function LogNote([string] $message){
    Write-Host $message
    Add-Content $processlog $message
    if ($global:gui){
        $Note.Text = $message
    }
}

# Download the file specified by url to the download location, can retry
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

# Downloads all the update files and makes the Installation Script
Function DownloadUpdates($urlist){
    New-Item -ItemType "file" -Path $installScript -Force

    ForEach($url in $urlist) {
        $downloadFile = $url -Split "/"
        $downloadFile = $downloadFile[$downloadFile.length - 1]
        $filePath = $downloadLocation + $downloadFile

        LogNote "Attempting download $url"
        Start-Job -ScriptBlock ${function:DownloadWithRetry} -ArgumentList $url, $filePath, 5

        #DownloadWithRetry -url $url -outFile "$downloadLocation$downloadFile" -retries 5
        Add-Content $installScript "Start-Process -Wait -FilePath `"$filePath`" -ArgumentList `"/s`", `"/l=```"$filePath.log```"`""
    }

    SpinWait
}

# Runs the install script as background job
Function InstallUpdates(){
    Start-Job -FilePath $installScript
    Write-Host | Get-Content $installScript
    LogNote "Installing updates... "
    SpinWait
}

# Runs Dell Command Update and makes XML report of available updates
Function CheckForUpdates() {
    # Initialize the update location
    mkdir -Path $downloadLocation -Force
    New-Item -ItemType "file" -Path $processlog -Force
    New-Item -ItemType "file" -Path $xmlcatalog -Force

    # Make background job
    $scriptBlok = {
        param ($dcucli, $xmlcatalog)
        Start-Process -Wait -FilePath $dcucli -ArgumentList "/report $xmlcatalog" -WindowStyle hidden
    }

    Start-Job -ScriptBlock $scriptBlok -ArgumentList $dcucli, $xmlcatalog
    LogNote "Checking System for Updates. Please wait... "

    # Async wait for background job
    SpinWait
    LogNote "Dell Command Update Client Finished"
}

# SpinWait is a workaround for the lack of async interop between WinForms and Powershell
function SpinWait() {
    [System.Windows.Forms.Application]::UseWaitCursor=$true
    if ($global:gui){$oldNote = $Note.Text}
    $spinner = ".oO@+-\|/-"

    While (@(Get-Job | Where-Object { $_.State -eq "Running" }).Count -ne 0)
    {
        Start-Sleep -Milliseconds 222
        if ($global:gui){ $Note.Text = $oldNote + $spinner.Substring($spinStep, 1) } 

        [System.Windows.Forms.Application]::DoEvents()
        $spinStep++
        if ($spinStep -gt $spinner.Length - 1) {$spinStep = 0}
    }

    # Clean up
    Remove-Job -State Completed
    Remove-Job -State Failed
    [System.Windows.Forms.Application]::UseWaitCursor=$false
}
