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
	exit 5
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
    Write-Error "Branch master diverges from origin/master. Please fix manully."
	Write-Error "You may want to reset master to orgin/master."
	Write-Host -NoNewLine "Press any key to exit"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	exit 4
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
