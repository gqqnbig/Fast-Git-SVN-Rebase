$password = $args[0] | ConvertTo-SecureString -asPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("QIQIGWRK2\git2svn",$password)
Start-Process -Credential $credential -FilePath "C:\Program Files\Git\git-bash.exe" -ArgumentList '--cd=C:\LoansPQ2-Git-SVN C:\Temp\GitToSvn\sync.sh'