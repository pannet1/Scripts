Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned


$Url = "https://github.com/pannet1/scripts/archive/main.zip"
$OutputZip = "C:\scripts.zip"
curl.exe -L -o $OutputZip $Url
