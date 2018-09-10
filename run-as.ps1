$password = $args[0] | ConvertTo-SecureString -asPlainText -Force

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "C:\Program Files\Git\git-bash.exe"
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false
$pinfo.Arguments =  'C:\Temp\GitToSvn\sync.sh'
$pinfo.Domain = "."
$pinfo.UserName="git2svn"
$pinfo.Password = $password
# The WorkingDirectory property must be set if UserName and Password are provided. https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.username
# If the property is not set, Start method will throw error "The directory name is invalid".
$pinfo.WorkingDirectory = "C:\LoansPQ2-Git-SVN"

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
#Do Other Stuff Here....
$p.WaitForExit()
exit $p.ExitCode