param
(
  # Load Test run id
  [string] $testRunId,
  # Load Test data plane endpoint
  [string] $apiEndpoint,
  # Load Test data plane api version
  [string] $apiVersion,
  [bool]$verbose = $False
)

. "$PSScriptRoot/common.ps1"

$urlRoot = $apiEndpoint + "/testruns/" + $testRunId

$url = $urlRoot + "?api-version=" + $apiVersion

# Secure string to use access token with Invoke-RestMethod in Powershell
$accessTokenSecure = ConvertTo-SecureString -String $accessToken -AsPlainText -Force

Invoke-RestMethod `
  -Uri $url `
  -Method GET `
  -Authentication Bearer `
  -Token $accessTokenSecure `
  -Verbose:$verbose

Remove-Item $accessTokenFileName
