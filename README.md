# Useful-Scripts
 Useful Powershell and other scripts

* CompareHash.ps1 -
Compare given hash with exisiting file hash. Handles MD5, SHA1, SHA256, SHA384, and SHA512)

* DeleteInboxRules.ps1 - 
Connect to your Exchange Online tenant and view/delete rules that may be malicious.

* DuoApiDump.ps1 - 
Dump info from the DUO Admin APIO

* TNCMultiple.ps1 - 
Run multiple Test-NetConnections against multiple IPs/Ports

* base64.ps1 - 
Simple Base64 Encoder/Decoder.

* base64.py -
Simple Base64 Encoder/Decoder written in python.

* credential_dump_mass_valdiation.ps1 - 
Select a CSV (username,password) of a credential dump. This will lookup SAMAccountName from emails if needed, and test the creds for validity. Will dump several files with the results.

* updateff.sh *
Update Local Binary version of Firefox from the remote source. Check to see if it is a newer version first, if not, do nothing. (Note: it is set as an alias as i just add it to bashrc. Remove alias='' if you want to run as a script).
