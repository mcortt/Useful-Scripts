# Load assembly for OpenFileDialog
Add-Type -AssemblyName System.Windows.Forms

# Import the ImportExcel module
Install-Module -Name ImportExcel -Scope CurrentUser

function New-duoRequest {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNull()]
        $apiHost,

        [Parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNull()]
        $apiEndpoint,

        [Parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNull()]
        $apiKey,

        [Parameter(Mandatory = $true, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNull()]
        $apiSecret,

        [Parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNull()]
        $requestMethod = 'GET',

        [Parameter(Mandatory = $false, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNull()]
        [System.Collections.Hashtable]$requestParams
    )

    $date = (Get-Date).ToUniversalTime().ToString("ddd, dd MMM yyyy HH:mm:ss -0000")

    $formattedParams = ($requestParams.Keys | Sort-Object | ForEach-Object { $_ + "=" + [uri]::EscapeDataString($requestParams.$_) }) -join "&"

    #DUO Params formatted and stored as bytes with StringAPIParams
    $requestToSign = (@(
        $Date.Trim(),
        $requestMethod.ToUpper().Trim(),
        $apiHost.ToLower().Trim(),
        $apiEndpoint.Trim(),
        $formattedParams
    ).trim() -join "`n").ToCharArray().ToByte([System.IFormatProvider]$UTF8)

    #Hash out some secrets 
    $hmacsha1 = [System.Security.Cryptography.HMACSHA1]::new($apiSecret.ToCharArray().ToByte([System.IFormatProvider]$UTF8))
    $hmacsha1.ComputeHash($requestToSign) | Out-Null
    $authSignature = [System.BitConverter]::ToString($hmacsha1.Hash).Replace("-", "").ToLower()

    #Create the Authorization Header
    $authHeader = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $apiKey, $authSignature)))

    #Create our Parameters for the webrequest - Easy @Splatting!
    $httpRequest = @{
        URI         = ('https://{0}{1}' -f $apiHost, $apiEndpoint)
        Headers     = @{
            "X-Duo-Date"    = $Date
            "Authorization" = "Basic: $authHeader"
        }
        Body        = $requestParams
        Method      = $requestMethod
        ContentType = 'application/x-www-form-urlencoded'
    }

    $httpRequest
}

function ConvertTo-FlatObject {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$InputObject
    )

    $output = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.Value -is [PSObject]) {
            $nestedObject = ConvertTo-FlatObject -InputObject $property.Value
            foreach ($nestedProperty in $nestedObject.PSObject.Properties) {
                $output["$($property.Name).$($nestedProperty.Name)"] = $nestedProperty.Value
            }
        } elseif ($property.Value -is [Array]) {
            if ($property.Value[0] -is [String]) {
                $output["$($property.Name)"] = $property.Value -join ', '
            } else {
                for ($i = 0; $i -lt $property.Value.Length; $i++) {
                    $nestedObject = ConvertTo-FlatObject -InputObject $property.Value[$i]
                    foreach ($nestedProperty in $nestedObject.PSObject.Properties) {
                        $output["$($property.Name)[$i].$($nestedProperty.Name)"] = $nestedProperty.Value
                    }
                }
            }
        } else {
            $output[$property.Name] = $property.Value
        }
    }

    return New-Object -TypeName PSObject -Property $output
}

# Prompt the user for API details
$ApiHost      = (Read-Host -Prompt 'Enter your API Host') -replace "`r|`n"
$ApiKey       = (Read-Host -Prompt 'Enter your API Integration Key') -replace "`r|`n"
$ApiSecret    = (Read-Host -Prompt 'Enter your API Secret Key') -replace "`r|`n"
$UserEndpoint = (Read-Host -Prompt 'Enter the specific API Endpoint (it will be appended to /admin/v1/)') -replace "`r|`n"
$ApiEndpoint  = "/admin/v1/$UserEndpoint"

# Show dialog for input file
$openFileDialog             = New-Object System.Windows.Forms.OpenFileDialog
$openFileDialog.Title       = 'Select the input text file'
$openFileDialog.Filter      = 'Text files (*.txt)|*.txt'
if ($openFileDialog.ShowDialog() -eq 'OK') {
    $InputTxtFile = $openFileDialog.FileName
}

# Show dialog for output file
$saveFileDialog             = New-Object System.Windows.Forms.SaveFileDialog
$saveFileDialog.Title       = 'Select the output Excel file'
$saveFileDialog.Filter      = 'Excel files (*.xlsx)|*.xlsx'
if ($saveFileDialog.ShowDialog() -eq 'OK') {
    $OutputExcelFile = $saveFileDialog.FileName
}

# Read input data from the input text file
$inputData = Get-Content -Path $InputTxtFile

# Array to store results
$results = @()

# Loop through each piece of input data
foreach ($data in $inputData) {
    # Create the request parameters
    $requestParams = @{
        number = $data
    }

    # Create the request object using New-DuoRequest function
    $request = New-DuoRequest -apiHost $ApiHost -apiEndpoint $ApiEndpoint -apiKey $ApiKey -apiSecret $ApiSecret -requestParams $requestParams

    try {
        # Make the API call using Invoke-RestMethod
        $response = Invoke-RestMethod -Uri $request.URI -Method $request.Method -Headers $request.Headers -Body $request.Body -ContentType $request.ContentType

        if ($response.stat -eq "OK") {
            # Convert the response to a flat PSObject and add it to the results array
            $flatResponse = ConvertTo-FlatObject -InputObject $response.response
            $flatResponse | Add-Member -NotePropertyName "InputData" -NotePropertyValue $data -PassThru | Out-Null
            $results += $flatResponse
        }
    } catch {
        Write-Host "Failed to make the API call for input $data. Error: $_"
    }
}

# Get all available properties from the first result
if ($results.Count -gt 0) {
    $allProperties = $results[0].PSObject.Properties.Name
    Write-Host "Available properties:"
    $allProperties | ForEach-Object { Write-Host $_ }

    # Prompt the user to select properties to export
    $selectedProperties = $allProperties | Out-GridView -Title "Select properties to export" -OutputMode Multiple

    # Export the selected properties to the output Excel file
    if ($selectedProperties) {
        $results | ForEach-Object {
            $row     = $_
            $rowData = @{
                InputData = $row.InputData
            }
            foreach ($prop in $selectedProperties) {
                $rowData[$prop] = $row.$prop
            }
            New-Object PSObject -Property $rowData
        } | Export-Excel -Path $OutputExcelFile -AutoSize -FreezeTopRow
    } else {
        Write-Host "No properties selected."
    }
} else {
    Write-Host "No results found."
}
