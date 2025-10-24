$Url = "https://github.com/<OWNER>/<REPOSITORY>/archive/<BRANCH_OR_TAG>.zip"
$OutputZip = "C:\Path\To\Save\Repo.zip"

curl.exe -L -o $OutputZip $Url
