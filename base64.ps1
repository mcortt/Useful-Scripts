param(
    [Parameter(Mandatory=$false)]
    [string]$encode,
    [Parameter(Mandatory=$false)]
    [string]$decode
)

function Base64Encode($string) {
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($string)
    $encoded = [System.Convert]::ToBase64String($bytes)
    return $encoded
}

function Base64Decode($string) {
    $decodedBytes = [System.Convert]::FromBase64String($string)
    $decoded = [System.Text.Encoding]::Unicode.GetString($decodedBytes)
    return $decoded
}

if ($encode) {
    $result = Base64Encode $encode
    Write-Output $result
} elseif ($decode) {
    $result = Base64Decode $decode
    Write-Output $result
} else {
    $option = Read-Host -Prompt "Do you want to encode or decode a string? (e/d)"
    if ($option -eq 'e') {
        $stringToEncode = Read-Host -Prompt "Please enter the string to encode"
        $result = Base64Encode $stringToEncode
        Write-Output $result
    } elseif ($option -eq 'd') {
        $stringToDecode = Read-Host -Prompt "Please enter the string to decode"
        $result = Base64Decode $stringToDecode
        Write-Output $result
    } else {
        Write-Output "Invalid option"
    }
}