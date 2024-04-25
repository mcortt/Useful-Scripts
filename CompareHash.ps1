function Compare-Hash {
    # Load assemblies
    Add-Type -AssemblyName System.Windows.Forms

    # Create OpenFileDialog
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.InitialDirectory = 'C:\Users\mcort\Downloads'

    # Create a new form to set TopMost property
    $form = New-Object System.Windows.Forms.Form
    $form.TopMost = $true

    # Show OpenFileDialog
    $result = $openFileDialog.ShowDialog($form)

    # If user selected a file
    if ($result -eq 'OK') {
        $file = $openFileDialog.FileName

        # Ask for a hash
        $hash = Read-Host -Prompt 'Enter published hash'

        # Detect the type of hash
        $hashType = $null
        switch ($hash.Length) {
            32 { $hashType = 'MD5' }
            40 { $hashType = 'SHA1' }
            64 { $hashType = 'SHA256' }
            96 { $hashType = 'SHA384' }
            128 { $hashType = 'SHA512' }
            default { Write-Host "Unknown hash type."; exit }
        }

        # Calculate the hash of the file
        $calculatedHash = Get-FileHash -Path $file -Algorithm $hashType | ForEach-Object { $_.Hash }

        # Compare the calculated hash with the provided hash
        if ($calculatedHash -eq $hash) {
            Write-Host "Hashes match. ✔️" -ForegroundColor Green
        } else {
            Write-Host "HASHES DO NOT MATCH! ⛔" -ForegroundColor Red
        }
    }
}

# Create alias
Set-Alias -Name ch -Value Compare-Hash
Set-Alias -Name comphash -Value Compare-Hash