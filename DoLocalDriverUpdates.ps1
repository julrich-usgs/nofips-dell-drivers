# DoLocalDriverUpdates.ps1

# If not running as Administrator, escalate self
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
        Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
        Exit
    }
}



Add-Type -AssemblyName System.Windows.Forms
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Dell Driver Updates"
$Form.BackColor = "DarkGray"
$Form.AutoSize = $True

$Note = New-Object System.Windows.Forms.Label
$Note.Text = "Status Updates"
$Note.AutoSize = $True

$Form.Controls.Add($Note)

$Note.Text = "Check the updates you want to install"

$btn_Scan = New-Object system.windows.Forms.Button 
$btn_Scan.Text = "Scan for Updates" 
$btn_Scan.BackColor = "Yellow" 
$btn_Scan.Width = 249 
$btn_Scan.Height = 30 
$btn_Scan.Dock = "Bottom"

$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.Y = 25

$btn_Scan.Location = $System_Drawing_Point

$Form.Controls.Add($btn_Scan)
$btn_Scan.Add_Click({checkUpdates})

$processlog = $PSScriptRoot + "\DellDrivers\process.log"
New-Item -ItemType "file" -Path $processlog -Force

$xmlcatalog = $PSScriptRoot + "\DellDrivers\driverUpdates.xml"

function DownloadWithRetry([string] $url, [string] $downloadLocation, [int] $retries)
{
    while($true)
    {
        try
        {
            $Note.Text = "attempting download $url"
            Invoke-WebRequest $url -OutFile $downloadLocation -UseBasicParsing
            $Note.Text = "download succeeded"
            break
        }
        catch
        {
            $exceptionMessage = $_.Exception.Message
            Write-Host "Failed to download '$url': $exceptionMessage"
            $Note.Text = "download failed"
            if ($retries -gt 0) {
                $retries--
                Write-Host "Waiting 10 seconds before retrying. Retries left: $retries"
                $Note.Text = "Waiting 10 seconds.  Retries left: $retries"
                Start-Sleep -Seconds 10
            }
            else
            {
                $Note.Text = "Max retries reached download failed $url"
                $exception = $_.Exception
                throw $exception
            }
        }
    }
}

 Function runUpdates () {
    $Form.Controls.Remove($btn_Execute)
    $Note.Text = "Preparing for updates"
    $downloadLocation = $PSScriptRoot + "\DellDrivers\"
    mkdir -Path $downloadLocation -Force
    $installScript = $downloadLocation + "install.bat"
    New-Item -ItemType "file" -Path $installScript -Force
    $Note.Text = "Starting downloads"
    foreach($update in $Checkboxes)
    {
        if($update.Checked)
        {
            $downloadFile = $update.AccessibleName -Split "/"
            $downloadFile = $downloadFile[$downloadFile.length-1]
            DownloadWithRetry -url $update.AccessibleName -downloadLocation "$downloadLocation$downloadFile" -retries 5
            Add-Content $installScript "start /wait $downloadLocation$downloadFile /s /l=`"$PSScriptRoot\$downloadFile.log`""
        }
    }
    
    $Note.Text = "Done with downloads"
    $Note.Text = "Installing updates"
    Start-Process $installScript -Wait -NoNewWindow
    $Note.Text = "Installation Finished.  You can close this window"
}

Function checkUpdates() {
    New-Item -ItemType "file" -Path $xmlcatalog -Force
    $dcucli = $PSScriptRoot + "\dcu-cli.exe"
    $Note.Text = "Checking System for Updates.  Please wait..."
    Start-Process -Wait -FilePath $dcucli -ArgumentList "/report $xmlcatalog" -WindowStyle hidden
    $Note.Text = "Dell Command Update Client Finished"
    displayUpdates
}

Function displayUpdates() {
    $Note.Text = "Processing update catalog file"
    [xml]$XmlDocument = Get-Content $xmlcatalog

    if($XmlDocument.Count -lt 1)
    {
        $Note.Text = "No updates found"
        Return 1
    }

    $XmlDocument.GetType().FullName
    
    $CheckBoxCounter = 1
    
    $global:CheckBoxes = foreach($Label in $XmlDocument.updates.update) {
        $CheckBox = New-Object System.Windows.Forms.CheckBox        
        $CheckBox.UseVisualStyleBackColor = $True
        $System_Drawing_Size = New-Object System.Drawing.Size
        $System_Drawing_Size.Width = 800
        $System_Drawing_Size.Height = 34
        $CheckBox.Size = $System_Drawing_Size
        $CheckBox.TabIndex = 2

        $CheckBox.Text = $Label.name +" - "+ $Label.version +" - "+ $Label.date +" - "+ $Label.urgency
        $CheckBox.AccessibleName = "https://"+$Label.file 
        $CheckBox.Checked = $true

        $System_Drawing_Point = New-Object System.Drawing.Point
        $System_Drawing_Point.X = 27
        $System_Drawing_Point.Y = 60 + (($CheckBoxCounter - 1) * 31)
        $CheckBox.Location = $System_Drawing_Point
        $CheckBox.DataBindings.DefaultDataSourceUpdateMode = 0

        $CheckBox.Name = "CheckBox$CheckBoxCounter"

        $Form.Controls.Add($CheckBox)
        $CheckBox
        $CheckBoxCounter++
    }

    $Note.Text = "Put a check next to the updates you want to install"
    
    $btn_Execute = New-Object system.windows.Forms.Button 
    $btn_Execute.Text = "Install Updates" 
    $btn_Execute.BackColor = "Green" 
    $btn_Execute.Width = 249 
    $btn_Execute.Height = 30 

    $System_Drawing_Point.Y = 25
    $btn_Execute.Location = $System_Drawing_Point
    
    $Form.Controls.Remove($btn_Scan)
    $Form.Controls.Add($btn_Execute)
    $btn_Execute.Add_Click({runUpdates})
}



$Form.ShowDialog()