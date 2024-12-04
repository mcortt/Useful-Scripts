# Function to show the Windows File Dialog for file selection
function Select-File {
    Add-Type -AssemblyName System.Windows.Forms
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $fileDialog.Filter = "Text files (*.txt)|*.txt|All files (*.*)|*.*"
    $fileDialog.Title = "Select a file containing machine names"
    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $fileDialog.FileName
    } else {
        return $null
    }
}

# Function to show the Windows Save File Dialog
function Save-File {
    Add-Type -AssemblyName System.Windows.Forms
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    $saveDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
    $saveDialog.Title = "Select where to save the IP addresses"
    if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $saveDialog.FileName
    } else {
        return $null
    }
}

# Prompt the user to select the input file
$machineListPath = Select-File

if ($machineListPath -and (Test-Path $machineListPath)) {
    # Prompt the user to select the output file
    $outputFilePath = Save-File

    if ($outputFilePath) {
        # Read all machine names from the file
        $machines = Get-Content $machineListPath

        # Create an output list for storing results
        $results = @()

        foreach ($machine in $machines) {
            try {
                # Get the IP address of the machine
                $ipEntry = [System.Net.Dns]::GetHostAddresses($machine) |
                           Where-Object { $_.AddressFamily -eq 'InterNetwork' }

                if ($ipEntry) {
                    $results += [PSCustomObject]@{
                        MachineName = $machine
                        IPAddress   = $ipEntry.IPAddressToString
                    }
                } else {
                    $results += [PSCustomObject]@{
                        MachineName = $machine
                        IPAddress   = "No IPv4 address found"
                    }
                }
            } catch {
                # Handle any errors (e.g., machine not found)
                $results += [PSCustomObject]@{
                    MachineName = $machine
                    IPAddress   = "Error: $_"
                }
            }
        }

        # Export results to the selected file
        $results | Export-Csv -Path $outputFilePath -NoTypeInformation -Encoding UTF8

        Write-Output "IP addresses retrieved and saved to $outputFilePath"
    } else {
        Write-Output "No output file selected. Operation canceled."
    }
} else {
    Write-Output "No input file selected or the file does not exist."
}
