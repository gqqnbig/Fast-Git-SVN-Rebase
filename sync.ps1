function Get-LatestSvnRevision([string]$filePath)
{
    if((Test-Path $filePath -PathType Leaf) -eq $false)
    {
        return 0
    }
	$bytes = [System.IO.File]::ReadAllBytes($filePath)
    $versionBytes = $bytes[-24..-21]
    if([BitConverter]::IsLittleEndian)
    {
        [Array]::Reverse($versionBytes);
    }
    $revisionNumber= [bitconverter]::ToInt32($versionBytes,0)
    return $revisionNumber
}

function TimedPrompt([string]$prompt, [int]$secondsToWait){   
    Write-Host -NoNewline $prompt
    $secondsCounter = 0
    $subCounter = 0
    While ( (!$host.ui.rawui.KeyAvailable) -and ($count -lt $secondsToWait) ){
        start-sleep -m 10
        $subCounter = $subCounter + 10
        if($subCounter -eq 1000)
        {
            $secondsCounter++
            $subCounter = 0
            Write-Host -NoNewline "."
        }       
        If ($secondsCounter -eq $secondsToWait) { 
            Write-Host "`r`n"
            return $false;
        }
    }
    Write-Host "`r`n"
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    return $true;
}

$ErrorActionPreference = "Stop"
[System.IO.Directory]::SetCurrentDirectory($PWD)

# `git svn info` may hang up, so I have to use Select-String.
if([String]::IsNullOrWhitespace($(Select-String svn-remote .git/config)))
{
    Write-Host "This is not a git-svn repository. You have to run ``git svn init ...``." -ForegroundColor Red
	Write-Host -NoNewLine "Press any key to exit"
	$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 5
}

if([String]::IsNullOrEmpty($args[0]))
{
    Write-Host "Password is missing." -ForegroundColor Red
    Write-Host "Call the script like"
    Write-Host "`t$(Split-Path -leaf $PSCommandpath) password123"
    exit 6
}

git config --local gc.auto 0

# update trunk 
git checkout trunk
git pull origin trunk

# update master 
git checkout master

try
{
    git pull --ff-only origin master
}
catch
{
	Write-Host "Branch master diverges from origin/master. Please fix manully." -ForegroundColor Red
	Write-Host "You may want to reset master to orgin/master." -ForegroundColor Red
	Write-Host -NoNewLine "Press any key to exit"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 4
}

$svnMetadataFolder="\\CYBERTRON\loanspq\git\svn metadata\LoansPQ2-Git-SVN"
$backupFiles = Get-ChildItem -Directory $svnMetadataFolder | Sort-Object -Property LastWriteTime
# Index 0 is the oldest backup.
$sharedRev=Get-LatestSvnRevision("$($backupFiles[-1].FullName)\svn\refs\remotes\git-svn\.rev_map.b750ebf6-c7df-ed4a-bdf3-f739ba673275")
$myRev=Get-LatestSvnRevision('.git\svn\refs\remotes\git-svn\.rev_map.b750ebf6-c7df-ed4a-bdf3-f739ba673275')

Write-Verbose "sharedRev: $sharedRev"
Write-Verbose "myRev: $myRev"

if( $sharedRev -gt $myRev)
{
    Write-Host -NoNewline  "Shared rev map (r$sharedRev) is newer than local revision (r$myRev). Using the shared one... " -ForegroundColor Green

    # $null = ... swallows output
	if((Test-Path '.git\svn\refs\remotes\git-svn\' -PathType Container) -eq $false)
	{ $null = mkdir '.git\svn\refs\remotes\git-svn\' -ErrorAction SilentlyContinue }
	cp "$($backupFiles[-1].FullName)\svn\refs\remotes\git-svn\*" '.git\svn\refs\remotes\git-svn\'

	if((Test-Path '.git\refs\remotes\' -PathType Container) -eq $false)
	{ $null = mkdir '.git\refs\remotes\' -ErrorAction SilentlyContinue }
	cp "$($backupFiles[-1].FullName)\refs\remotes\git-svn" '.git\refs\remotes\'

	Write-Host "OK" -ForegroundColor Green
}

#sanity check to make sure trunk aligns with git-svn label 
if($(git rev-list -1 trunk) -ne $(git rev-list -1 git-svn))
{
    Write-Warning "trunk doesn't align with git-svn!"

	if($(git merge-base --is-ancestor git-svn trunk;$?))
    {
		echo "git-svn is behind of trunk. Reset trunk to git-svn."
		# current branch is master, so I can directly move the pointer of trunk.
		git branch -f trunk git-svn
		git push --force-with-lease origin trunk
    }
	elseif ($(git merge-base --is-ancestor trunk git-svn;$?))
    {
		echo "git-svn is ahead of trunk. Reset trunk to git-svn."
		# current branch is master, so I can directly move the pointer of trunk.
        # may not need to do anything
		git branch -f trunk git-svn
		git push --force-with-lease origin trunk 
    }
	else
    {
		Write-Host "git-svn diverges from trunk." -ForegroundColor Red
	    Write-Host -NoNewLine "Press any key to exit"
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
		exit 1
	}
}

# pull changes from SVN to GIT
git svn rebase --use-log-author

$password = $args[0] | ConvertTo-SecureString -asPlainText -Force

# run `git svn dcommit` as the git2svn user.
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "git"
$pinfo.Arguments =  'svn dcommit  --add-author-from --use-log-author'
$pinfo.RedirectStandardError = $true; $pinfo.RedirectStandardOutput = $true; $pinfo.UseShellExecute = $false
$pinfo.Domain = "."; $pinfo.UserName="git2svn"; $pinfo.Password = $password
# The WorkingDirectory property must be set if UserName and Password are provided. https://docs.microsoft.com/en-us/dotnet/api/system.diagnostics.processstartinfo.username
# If the property is not set, Start method will throw error "The directory name is invalid".
$pinfo.WorkingDirectory = $PWD

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null
$p.WaitForExit()
if($p.ExitCode -ne 0)
{
    Write-Host $($p.StandardError.ReadToEnd()) -ForegroundColor Red
    exit $p.ExitCode
}

# align trunk to master (fast forward) 
git checkout trunk
git merge master

# push trunk and master back to origin;  the force with lease is to handle 
# the new svn metadata (from synching hash of svn revision) and force git to take change
git checkout master

try
{
    git push --force-with-lease=master  origin master trunk
}
catch
{
	Write-Host "Do you have the rewind permission on $(git remote get-url origin)?" -ForegroundColor Red
	Write-Host -NoNewLine "Press any key to exit"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 2
}

git gc --auto

# Remove old backups
if($backupFiles.Length -gt 9)
{
	$toDelete=$backupFiles.Length - 9
	echo "Delete $toDelete folders"
	for($i=0; $i -lt $toDelete; $i++)
	{
		echo  "Delete $($backupFiles[$i].FullName)"
		Remove-Item "$($backupFiles[$i].FullName)" -Recurse
	}
}


$newFolder="$svnMetadataFolder\$([DateTime]::Now.ToString("yyyyMMdd-HHmmss")).git"
# Copy the database file
$null = mkdir "$newFolder\svn\refs\remotes\git-svn\" 
cp ".git\svn\refs\remotes\git-svn\*" "$newFolder\svn\refs\remotes\git-svn\"

# Copy the git-svn pointer
$null = mkdir "$newFolder\refs\remotes\"
cp '.git\refs\remotes\git-svn' "$newFolder\refs\remotes\"

