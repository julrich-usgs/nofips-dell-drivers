# DoLocalDriverUpdates.ps1
#
# Include shared functions
. $PSScriptRoot\DellUpdateFunctions.ps1



# If not running as Administrator, escalate self
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`""
    Exit
}

# GUI Button to check for updates
Function Scan_Click() {
    $btn_Scan.Enabled = $false
    CheckForUpdates
    $btn_Scan.Enabled = $true

    If ((Get-Item $xmlcatalog).length -gt 0kb) {
        LogNote "Processing update catalog file"
        DisplayUpdates
    } Else {
        LogNote "No updates found"
        Return 1
    }
}

# Add checkboxen to GUI with update list
Function DisplayUpdates() {
    $Form.Controls.Remove($btn_Scan)
    [xml]$XmlDocument = Get-Content $xmlcatalog
    
    $CheckBoxCounter = 1
    $global:Checkboxes = foreach($update in $XmlDocument.updates.update) {
        $CheckBox = New-Object System.Windows.Forms.CheckBox
        $CheckBox.UseVisualStyleBackColor = $True
        $CheckBox.Size = [System.Drawing.Size]::new(800, 34)
        $CheckBox.TabIndex = 2
        $CheckBox.Text = $update.name +" - "+ $update.version +" - "+ $update.date +" - "+ $update.urgency +" - "+ $update.category
        $CheckBox.AccessibleName = "https://"+$update.file
        $CheckBox.Tag = $update.category
        $CheckBox.Checked = $true
        $CheckBox.Location = [System.Drawing.Point]::new(27, 60 + (($CheckBoxCounter - 1) * 31))
        $CheckBox.DataBindings.DefaultDataSourceUpdateMode = 0
        $CheckBox.Name = "CheckBox$CheckBoxCounter"
        $Form.Controls.Add($CheckBox)
        $CheckBox
        $CheckBoxCounter++
    }

    LogNote "Put a check next to the updates you want to install:"
    
    $btn_Execute = New-Object System.Windows.Forms.Button
    $btn_Execute.Name = "btnInstall"
    $btn_Execute.Text = "Install Updates" 
    $btn_Execute.BackColor = "Green" 
    $btn_Execute.Width = 249 
    $btn_Execute.Height = 30 
    $btn_Execute.Location = [System.Drawing.Point]::new(0,25)
    $btn_Execute.Dock = "Bottom"
    $btn_Execute.Add_Click({Execute_Click})
    $Form.Controls.Add($btn_Execute)
}

# GUI Button "btnInstall"
Function Execute_Click () {
    $Form.Controls["btnInstall"].Enabled = $false
    
    LogNote "Starting downloads"
    $urlist = [System.Collections.ArrayList]::new()
    foreach ($update in $global:Checkboxes)
    {
        if($update.Checked)
        {
            if ($update.Tag -like "*bios*" -or $update.name -like "*thunderbolt*"){
                SuspendAllBitlocker
            } 

            $urlist.Add($update.AccessibleName)
            $Form.Controls.Remove($update)
        }
    }

    DownloadUpdates $urlist

    LogNote "Done with downloads"

    InstallUpdates

    $Form.Controls["btnInstall"].Enabled = $true
}

# Create a GUI
$Global:gui = $True
Add-Type -AssemblyName System.Windows.Forms
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Dell Command Update"
$Form.BackColor = "DarkGray"
$Form.AutoSize = $True
$Form.Width = 800
$Form.StartPosition = "CenterScreen"

$Note = New-Object System.Windows.Forms.Label
$Note.Name = "StatusText"
$Note.Text = "Click button to check for updates"
$Note.AutoSize = $True
$Note.Padding = [System.Windows.Forms.Padding]::new(11)
$Note.MaximumSize = [System.Drawing.Size]::new($Form.Width, 0)
$Form.Controls.Add($Note)

$btn_Scan = New-Object system.windows.Forms.Button 
$btn_Scan.Text = "Scan for Updates" 
$btn_Scan.BackColor = "Yellow" 
$btn_Scan.Width = 249 
$btn_Scan.Height = 30 
$btn_Scan.Dock = "Bottom"
$btn_Scan.Location = [System.Drawing.Point]::new(25,25)
$btn_Scan.Add_Click({Scan_Click})
$btn_Scan.Enabled = $true
$Form.Controls.Add($btn_Scan)

# Show that GUI
$Form.ShowDialog($this)
