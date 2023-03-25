$GITHUB_PATH = "$env:USERPROFILE\Documents\GitHub"
$GITHUB_TOKEN = "INSERT-TOKEN-HERE"

function DownloadRelease($url, $outputFile) {
    Write-Host "Downloading $url..."
    $handler = New-Object System.Net.Http.HttpClientHandler
    $client = New-Object System.Net.Http.HttpClient -ArgumentList $handler
    $client.DefaultRequestHeaders.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new("token", $GITHUB_TOKEN)

    $response = $client.GetAsync($url).Result
    $response.EnsureSuccessStatusCode()

    $fs = [System.IO.File]::OpenWrite($outputFile)
    $response.Content.CopyToAsync($fs).Wait()
    $fs.Close()
}

function GetLastDownloadedVersion($repoPath) {
    $versionFile = Join-Path $repoPath "last_downloaded_version.txt"

    if (Test-Path $versionFile) {
        return Get-Content $versionFile
    } else {
        return $null
    }
}

function SetLastDownloadedVersion($repoPath, $version) {
    $versionFile = Join-Path $repoPath "last_downloaded_version.txt"
    Set-Content -Path $versionFile -Value $version
}

$repos = Get-ChildItem -Path $env:USERPROFILE\Documents\GitHub -Directory
$runspacePool = [runspacefactory]::CreateRunspacePool()
$runspacePool.SetMaxRunspaces(10)
$runspacePool.Open()

foreach ($repo in $repos) {
    try {
        $repoPath = $repo.FullName
        Write-Host "Updating $repoPath..."
        git -C $repoPath pull

        $repoInfo = git -C $repoPath config --get remote.origin.url
        $repoOwnerAndName = $repoInfo -replace '.*[:/]([^/]*)/([^/]*).git', '$1/$2'
        $releasesUrl = "https://api.github.com/repos/$repoOwnerAndName/releases"

        $headers = @{
            "Authorization" = "token $GITHUB_TOKEN"
            "User-Agent"    = "PowerShell"
        }

        $releasesResponse = Invoke-WebRequest -Uri $releasesUrl -Headers $headers
        $releases = (ConvertFrom-Json $releasesResponse.Content) | Where-Object { $_.assets.Count -gt 0 }

        if ($releases) {
            $latestRelease = $releases | Select-Object -First 1
            $lastDownloadedVersion = GetLastDownloadedVersion $repoPath

            if ($lastDownloadedVersion -ne $latestRelease.tag_name) {
                # Download the new release
                # ... (Rest of the script)

                SetLastDownloadedVersion $repoPath $latestRelease.tag_name
            } else {
                Write-Host "No new releases found for $repoPath."
            }
        } else {
            Write-Host "No new releases found for $repoPath."
        }
    } catch {
        Write-Host "Error fetching releases for ${repoPath}: $_"
    }
}

$runspacePool.Close()
$runspacePool.Dispose()

Write-Host "All repositories and releases updated!"