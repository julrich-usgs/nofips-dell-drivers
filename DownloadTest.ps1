# DownloadTest.ps1
#
#   Unit test of the DownloadUpdates function. Used to prove out multithreaded downloads.
#
# Include shared functions
. $PSScriptRoot\DellUpdateFunctions.ps1

$Global:gui = $false
$urlist = [System.Collections.ArrayList]::new()
$urlist.Add("https://downloads.dell.com/FOLDER06228963M/4/Dell-Command-Update-Application_68GJ6_WIN_3.1.2_A00.EXE")
$urlist.Add("https://downloads.dell.com/FOLDER05877897M/2/Intel-PCIe-Ethernet-Controller-Driver_VP20T_WIN_24.1.0.0_A13_01.EXE")

DownloadUpdates $urlist
