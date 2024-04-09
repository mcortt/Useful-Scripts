# Add the necessary types
Add-Type -AssemblyName System.Windows.Forms

# Function to validate an IP address
function IsValidIP($ip) {
    try {
        $null = [System.Net.IPAddress]::Parse($ip)
        return $true
    } catch {
        return $false
    }
}

# Ask for the IPs
$ips = @()
while ($true) {
    Write-Host "Enter the IPs to test (separated by commas, leave blank to select a file):"
    $ipInput = Read-Host -Prompt "IPs" -ErrorAction Stop
    if ([string]::IsNullOrWhiteSpace($ipInput)) {
        break
    }

    $ipInput = $ipInput.Split(',')
    $validIPs = $true
    foreach ($ip in $ipInput) {
        $ip = $ip.Trim()
        if (-not (IsValidIP($ip))) {
            Write-Host "Invalid IP: $ip. Please enter a valid IP address." -ForegroundColor Red
            $validIPs = $false
            break
        } else {
            $ips += $ip
        }
    }

    if ($validIPs) {
        break
    }
}

# If no IPs were entered, open the file dialog
if ($ips.Length -eq 0) {
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
}

# Ask for the ports
while ($true) {
    Write-Host "Enter the ports to test (separated by commas):"
    $ports = Read-Host -Prompt "Ports" -ErrorAction Stop
    $ports = $ports.Split(',')

    # Validate the ports
    $validPorts = $true
    foreach ($port in $ports) {
        $port = $port.Trim()
        if (-not ($port -as [int]) -or $port -lt 1 -or $port -gt 65535) {
            Write-Host "Invalid port: $port. Please enter a valid port number between 1 and 65535." -ForegroundColor Red
            $validPorts = $false
            break
        }
    }

    if ($validPorts) {
        break
    }
}

# Ask for the timeout
while ($true) {
    Write-Host "Enter the timeout (e.g., '1s' or '1000ms') or leave blank for default (2s):"
    $timeoutInput = Read-Host -Prompt "Timeout" -ErrorAction Stop

    # If the input is blank, set a default value
    if ([string]::IsNullOrWhiteSpace($timeoutInput)) {
        $timeout = 2
        break
    }

    # Parse the timeout
    $timeout = 0
    if ($timeoutInput -match "(\d+)(ms|s)") {
        $timeout = [int]$Matches[1]
        if ($Matches[2] -eq "ms") {
            $timeout = $timeout / 1000  # Convert to seconds
        }
        break
    } else {
        Write-Host "Invalid timeout. Please enter a number followed by 's' (for seconds) or 'ms' (for milliseconds)." -ForegroundColor Red
    }
}

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

        # Run the test with timeout
        $job = Start-Job -ScriptBlock { Test-NetConnection -ComputerName $using:ip -Port $using:port -InformationLevel Quiet }
        $result = $null
        if (Wait-Job -Job $job -Timeout $timeout) {
            $result = Receive-Job -Job $job
        }

        # Stop and remove the job
        Stop-Job -Job $job
        Remove-Job -Job $job

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