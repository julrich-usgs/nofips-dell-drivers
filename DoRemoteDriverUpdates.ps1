# DoRemoteDriverUpdates.ps1

$downloadLocation = $PSScriptRoot + "\DellDrivers\"
mkdir -Path $downloadLocation -Force
$processlog = $downloadLocation + "process.log"
New-Item -ItemType "file" -Path $processlog -Force
$xmlcatalog = $downloadLocation + "driverUpdates.xml"
New-Item -ItemType "file" -Path $xmlcatalog -Force
$dcucli = $PSScriptRoot + "\dcu-cli.exe"

Add-Content $processlog "Starting dell command update"
start-process -Wait -FilePath $dcucli -ArgumentList "/report $xmlcatalog"
Add-Content $processlog "Dell command update finished"
[xml]$XmlDocument = Get-Content $xmlcatalog
if($XmlDocument.Count -lt 1)
{
    Return "No updates found"
}

$XmlDocument.GetType().FullName

function DownloadWithRetry([string] $url, [string] $downloadLocation, [int] $retries)
{
    while($true)
    {
        try
        {
            Add-Content $processlog "Starting download"
            Invoke-WebRequest $url -OutFile $downloadLocation -UseBasicParsing
            Add-Content $processlog "Download successful"
            break
        }
        catch
        {
            $exceptionMessage = $_.Exception.Message
            Add-Content $processlog "Failed to download '$url': $exceptionMessage"
            if ($retries -gt 0) {
                $retries--
                Add-Content $processlog "Waiting 10 seconds before retrying. Retries left: $retries"
                Start-Sleep -Seconds 10
            }
            else
            {
                Add-Content $processlog "Max retries reached.  Skipping download"
                $exception = $_.Exception
                throw $exception
            }
        }
    }
}



$installScript = $downloadLocation + "install.bat"
New-Item -ItemType "file" -Path $installScript -Force

$updateNum = 1
$ttlUpdates = $XmlDocument.updates.update.Count
foreach($Label in $XmlDocument.updates.update) {
    $fulldlPath = "https://"+$Label.file
    Add-Content $processlog "Found Update..."
    $downloadFile = $fulldlPath -Split "/"
    $downloadFile = $downloadFile[$downloadFile.length-1]
    Add-Content $processlog "Entering Download Routine with parameters: $fulldlPath | $downloadLocation$downloadFile | retries=5"
    Write-Host "Downloading update $updateNum of $ttlUpdates"
    DownloadWithRetry -url $fulldlPath -downloadLocation "$downloadLocation$downloadFile" -retries 5
    Add-Content $processlog "writing to install.bat start /wait $downloadLocation$downloadFile /s /l=`"$PSScriptRoot\$downloadFile.log`""
    Add-Content $installScript "start /wait $downloadLocation$downloadFile /s /l=`"$PSScriptRoot\$downloadFile.log`""
    $updateNum++
}

Add-Content $processlog "Starting install.bat process"
Start-Process $installScript -Wait -NoNewWindow
Add-Content $processlog "Exiting Powershell"
