$ErrorActionPreference = "Stop"

function Invoke-NativeCommand() {
    $command = $args[0]
    $commandArgs = @()
    if ($args.Count -gt 1) {
        $commandArgs = $args[1..($args.Count - 1)]
    }

    & $command $commandArgs
    $result = $LASTEXITCODE

    if ($result -ne 0) {
        throw "$command $commandArgs exited with code $result."
    }
}

$opwd = "$pwd"
Invoke-NativeCommand zola build
Invoke-NativeCommand git worktree add $env:temp/lemondeploy gh-pages
Set-Location $env:temp/lemondeploy
Invoke-NativeCommand git checkout --orphan tmp-gh-pages
Remove-Item -R *
Move-Item $opwd/public/* .
Invoke-NativeCommand git add -A
Invoke-NativeCommand git commit -m "deploy github pages"
Invoke-NativeCommand git branch -D gh-pages
Invoke-NativeCommand git branch -m gh-pages
Invoke-NativeCommand git push -f origin gh-pages
Set-Location $opwd
Invoke-NativeCommand git worktree remove $env:temp/lemondeploy
Invoke-NativeCommand git push origin master