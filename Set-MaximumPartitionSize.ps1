#    Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
#
#        http://aws.amazon.com/apache2.0/
#
#    or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 
######################
# Configuration area #
######################
 
# Set log file time format. Default 2017-12-31_-_23-59-59
# Syntax and format: https://msdn.microsoft.com/en-us/powershell/reference/5.1/microsoft.powershell.utility/get-date
$LogTimeFormat = Get-Date -Format ('yyyy-MM-dd_-_HH-mm-ss')
 
# Set log file name and location. Default C:\Program Files\Amazon\Set-MaximumPartitionSize_2017-12-31_-_23-59-59.log
$LogFile = "C:\Program Files\Amazon\Set-MaximumPartitionSize_" + $LogTimeFormat + ".log"
 
 
 
###############
# Script area #
###############
 
# Start log
$LogStart = Get-Date
Write-Output "Log started: $(Get-Date -Format ('yyyy-MM-dd - HH-mm-ss'))" | Out-File $LogFile
 
# Get all block devices from meta-data
Write-Output "`r`nQuerying meta-data server..." | Out-File $LogFile -Append
$BlockDeviceMapping = Invoke-RestMethod http://169.254.169.254/latest/meta-data/block-device-mapping
$BlockDevices = $BlockDeviceMapping.Split([Environment]::NewLine)
$NumBlockDevices = $BlockDevices.Length-1
foreach ($BlockDevice in $BlockDevices) {
       if ($BlockDevice -ne 'ami') {
        Write-Output "Block device found in metadata: $BlockDevice" | Out-File $LogFile -Append
       }
}
 
# Get all disks from DiskPart
Write-Output "`r`nQuerying DiskPart..." | Out-File $LogFile -Append
$DiskPartDisks = ('list disk' | diskpart).Split([Environment]::NewLine)
$NumDiskPartDisks = $DiskPartDisks.Length-11
foreach ($i in 1..$NumDiskpartDisks) {
    Write-Output "Disk reported by DiskPart: $($DiskpartDisks[$i+8])" | Out-File $LogFile -Append
}
 
if ($NumBlockDevices -eq $NumDiskpartDisks) {
    Write-Output "All drives found" | Out-File $LogFile -Append
} else {
    Write-Output "Local and metadata drive information mismatch!" | Out-File $LogFile -Append
    $DrivesMissing = $true
}
 
# Get all online disks and partitions...
Write-Output "`r`nQuerying WMI for disks and partitions..." | Out-File $LogFile -Append
$DisksAndPartitions = (Get-WmiObject -Query "SELECT * FROM Win32_DiskPartition").Name | Out-File $LogFile -Append
 
# ... and their assigned drive letters
Write-Output "`r`nGetting assigned drive letters..." | Out-File $LogFile -Append
$DriveLetters = (Get-Partition).DriveLetter | Where-Object {$_}
$DriveLetters | Out-File $LogFile -Append
 
# Resize all drives to their maximum size
Write-Output "`r`nResizing all online drives..." | Out-File $LogFile -Append
foreach ($DriveLetter in $DriveLetters) {
       $Error.Clear()
       $SizeMax = (Get-PartitionSupportedSize -DriveLetter $DriveLetter).SizeMax # Shrink use case: Use .SizeMin to shrink volume as much as possible
       try {
              Resize-Partition -DriveLetter $DriveLetter -Size $SizeMax -ErrorAction Stop
        Write-Output "Drive $DriveLetter resized to maximum." | Out-File $LogFile -Append
       }
    catch [Microsoft.Management.Infrastructure.CimException] {
              Write-Output "! Drive $DriveLetter is already at maximum size" | Out-File $LogFile -Append
    }
       catch {
              Write-Output "! Error detected increasing drive $DriveLetter size" | Out-File $LogFile -Append
              Write-Output "! Exception: $($Error.Exception)" | Out-File $LogFile -Append
              Write-Output "! Exception: $($Error.Exception.Message)" | Out-File $LogFile -Append
       }
}
 
# Log a report when volumes mismatch. Most likely a drive attach/detach situation without instance reboot
if ($DrivesMissing) {
    Write-Output "`r`n! Numbers of meta-data block devices and DiskPart drives don't match" | Out-File $LogFile -Append
    Write-Output "! Usually happens when VDS service crashes. VDS Event Log output:" | Out-File $LogFile -Append
    Get-EventLog System | Where-Object {$_.EventID -eq '7031'} | Select-Object EntryType, EventID, TimeGenerated, Source, Message | Out-File $LogFile -Append
}
 
# Close log
$LogStop = Get-Date
Write-Output "`r`nLog stopped: $(Get-Date -Format ('yyyy-MM-dd - HH-mm-ss'))" | Out-File $LogFile -Append
Write-Output "Time elapsed: $($LogStop - $LogStart)" | Out-File $LogFile -Append
