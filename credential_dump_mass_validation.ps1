# Import the Active Directory module and add the necessary .NET assembly for GUI pop-ups
try {
    Import-Module ActiveDirectory
    Add-Type -AssemblyName System.Windows.Forms
}
catch {
    Write-Host "Error: Failed to load required modules. Ensure Active Directory RSAT is installed." -ForegroundColor Red
    return
}

#region User Input Functions
function Get-CsvFile {
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = "Please select the CSV file with user credentials"
    $dialog.Filter = "CSV Files (*.csv)|*.csv"
    if ($dialog.ShowDialog() -eq 'OK') {
        return $dialog.FileName
    }
    return $null # Return null if the user cancels
}

function Get-OutputFolder {
    $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $dialog.Description = "Please select the folder to save output files"
    $owner = New-Object System.Windows.Forms.NativeWindow
    $owner.AssignHandle((Get-Process -Id $PID).MainWindowHandle)
    $result = $dialog.ShowDialog($owner)
    $owner.ReleaseHandle()
    if ($result -eq 'OK') {
        return $dialog.SelectedPath
    }
    return $null
}

# --- 📁 Get User Input ---
$user_file = Get-CsvFile
if ([string]::IsNullOrEmpty($user_file)) {
    Write-Host "No CSV file selected. Script is exiting." -ForegroundColor Yellow
    return
}

$domain = Read-Host -Prompt "Please enter the domain name (e.g., contoso.com)"
if ([string]::IsNullOrEmpty($domain)) {
    Write-Host "No domain entered. Script is exiting." -ForegroundColor Yellow
    return
}

$outputFolder = Get-OutputFolder
if ([string]::IsNullOrEmpty($outputFolder)) {
    Write-Host "No output folder selected. Script is exiting." -ForegroundColor Yellow
    return
}

Write-Host "✅ Inputs received. Starting process..." -ForegroundColor Cyan

# --- Load data from the selected CSV ---
try {
    # Specify headers to ensure correct mapping even if file has different/no headers
    $data = Import-Csv -Path $user_file -Header "Username", "Password"
} catch {
    Write-Host "Error: Failed to read CSV file at '$user_file'." -ForegroundColor Red
    Write-Host "Ensure the file exists and is not open." -ForegroundColor Red
    return # Exit the script
}

#region AD Functions
Function Get-UsernameFromEmail {
    param($email)
    $user = Get-ADUser -Filter "mail -eq '$email' -or ProxyAddresses -eq 'smtp:$email'" -Property SamAccountName -ErrorAction SilentlyContinue
    if ($user) { return $user.SamAccountName }
    else {
        $assumedUsername = ($email -split '@')[0]
        $assumedUser = Get-ADUser -Filter "SamAccountName -eq '$assumedUsername'" -ErrorAction SilentlyContinue
        if ($assumedUser) { return $assumedUsername }
        else { return $null }
    }
}

Function Test-UserExists {
    param($username)
    try {
        Get-ADUser -Identity $username -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

Function Get-UserDetails {
    param($username)
    try {
        $properties = 'DisplayName', 'GivenName', 'Surname', 'mail', 'Enabled', 'LastLogonDate', 'PasswordLastSet', 'Created'
        return Get-ADUser -Identity $username -Properties $properties
    } catch {
        Write-Host "Failed to get details for $username" -ForegroundColor Red
        return $null
    }
}

Function Test-ADAuthentication {
    param($usernameWithDomain, $password)
    try {
        $entry = New-Object System.DirectoryServices.DirectoryEntry("", $usernameWithDomain, $password)
        if ($null -ne $entry.Name) { return $true }
    } catch { return $false }
    return $false
}
#endregion

# --- Dynamically define output file paths based on selected folder ---
$validUsernamesFilePath   = Join-Path -Path $outputFolder -ChildPath "valid_usernames.txt"
$invalidUsernamesFilePath = Join-Path -Path $outputFolder -ChildPath "invalid_usernames.txt"
$validUserDetailsFilePath = Join-Path -Path $outputFolder -ChildPath "valid_user_details.txt"
$invalidUserDetailsFilePath = Join-Path -Path $outputFolder -ChildPath "invalid_user_details.txt"

# --- Clear previous content from the output files ---
Clear-Content -Path $validUsernamesFilePath, $invalidUsernamesFilePath, $validUserDetailsFilePath, $invalidUserDetailsFilePath -ErrorAction SilentlyContinue

# --- Main processing loop ---
foreach($row in $data) {
    if ([string]::IsNullOrWhiteSpace($row.Username) -or [string]::IsNullOrWhiteSpace($row.Password)) {
        Write-Host "Skipping row with blank username or password." -ForegroundColor Yellow
        continue
    }

    $input = $row.Username
    $password = $row.Password
    $username = if ($input -match "@") { Get-UsernameFromEmail $input } else { $input }

    if ($username -and (Test-UserExists $username)) {
        $userDetails = Get-UserDetails $username
        if ($userDetails) {
            $userDetailsString = $userDetails | Format-List | Out-String
            
            if (Test-ADAuthentication -usernameWithDomain "$domain\$username" -password $password) {
                Write-Host "$username :: credentials VALID" -ForegroundColor Green
                
                # Appends "username,password" to the valid usernames file
                "$username,$password" | Add-Content -Path $validUsernamesFilePath
                
                $userDetailsString | Add-Content -Path $validUserDetailsFilePath
            } else {
                Write-Host "$username :: credentials INVALID" -ForegroundColor Red
                $username | Add-Content -Path $invalidUsernamesFilePath
                $userDetailsString | Add-Content -Path $invalidUserDetailsFilePath
            }
        }
    } else {
        Write-Host "$input :: user does not exist in Active Directory" -ForegroundColor Yellow
    }
}

# 🚨 SECURITY WARNING: The file 'valid_usernames.txt' contains passwords in plain text.
# Handle this file with extreme care and delete it securely when finished.
Write-Host "`n--- Script Finished ---`nResults saved to '$outputFolder'" -ForegroundColor Cyan
Write-Host "🚨 SECURITY WARNING: The file 'valid_usernames.txt' contains plain text passwords." -ForegroundColor Yellow