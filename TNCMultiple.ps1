# Add the necessary types
Add-Type -AssemblyName System.Windows.Forms

# Create an OpenFileDialog object
$openFileDialog = New-Object System.Windows.Forms.OpenFileDialog

# Show the OpenFileDialog
$result = $openFileDialog.ShowDialog()

# Check the result
if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
    $filePath = $openFileDialog.FileName
} else {
    Write-Host "No file selected."
    return
}

# Read the file and parse the IPs
$ips = Get-Content $filePath -ErrorAction Stop
if ($ips -eq $null -or $ips.Length -eq 0) {
    Write-Host "No IPs found in the file."
    return
}

# Ask for the ports
Write-Host "Enter the ports to test (separated by commas):"
$ports = Read-Host -Prompt "Ports" -ErrorAction Stop
$ports = $ports.Split(',')

# Initialize the lists for passed and failed tests
$passed = @()
$failed = @()

# Calculate total tests
$totalTests = $ips.Length * $ports.Length
$currentTest = 0

# Loop over each IP and port
for ($i = 0; $i -lt $ips.Length; $i++) {
    $ip = $ips[$i].Trim()
    for ($j = 0; $j -lt $ports.Length; $j++) {
        $port = $ports[$j].Trim()

        # Update the progress bar
        $currentTest++
        $status = "Testing $($ip):$($port)... ($($currentTest) / $($totalTests))"
        Write-Progress -Activity "Running Tests" -Status $status -PercentComplete (($currentTest / $totalTests) * 100)

        # Run the test
        $result = Test-NetConnection -ComputerName $ip -Port $port -InformationLevel Quiet 3>$null

        # Add the result to the appropriate list
        if ($result) {
            $passed += "$($ip):$($port)"
        } else {
            $failed += "$($ip):$($port)"
        }
    }
}

# Print the results
Write-Host "`nTotal tests: $($totalTests)"

if ($passed.Length -gt 0) {
    Write-Host "`nTotal passed: $($passed.Length) out of $($totalTests)" -ForegroundColor Green
    $passed | ForEach-Object { Write-Host $_ -ForegroundColor Green }
}

if ($failed.Length -gt 0) {
    Write-Host "`nTotal failed: $($failed.Length) out of $($totalTests)" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host $_ -ForegroundColor Red }
}

# Pause until the user hits a key
Read-Host -Prompt "`nPress any key to exit..."