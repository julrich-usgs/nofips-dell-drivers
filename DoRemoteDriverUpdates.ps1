# DoRemoteDriverUpdates.ps1
#
# Include shared functions
. $PSScriptRoot\DellUpdateFunctions.ps1



# Setup Environment
$Global:gui = $false

CheckForUpdates

# Stop here if there are no updates found
If ((Get-Item $xmlcatalog).length -gt 0kb) {
    Add-Content $processlog "Processing update catalog file"
    [xml]$XmlDocument = Get-Content $xmlcatalog
} Else {
    Add-Content $processlog "No updates found"
    Return 1
}

# Make URLs from each update in XML file
$updateNum = 0
$urlist = [System.Collections.ArrayList]::new()
foreach($update in $XmlDocument.updates.update) {
    $urlist.Add("https://"+$update.file)
    Add-Content $processlog "Found Update: $urlist[$updateNum]"
    $updateNum++

    if($update.type -like "*bios*" -or $update.category -like "*bios*" -or $update.name -like "*thunderbolt*"){
        SuspendAllBitlocker
    }
}

Add-Content $processlog "Downloading all updates found"
DownloadUpdates $urlist

InstallUpdates
