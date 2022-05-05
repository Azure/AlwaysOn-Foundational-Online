param
(
  # Load Test Id
  [string] $loadTestId,
  # Load Test data plane endpoint
  [string] $apiEndpoint,
  # Load Test data plane api version
  [string] $apiVersion,
  [string] $testRunName,
  [string] $testRunDescription,
  [int] $testRunVUsers,
  [bool]$verbose = $False,
  [bool]$pipeline = $False 
)

. "$PSScriptRoot/common.ps1"

function GetTestRunBody {
    param
    (
        [string] $testId,
        [string] $testRunName,
        [string] $description,
        [string] $testRunId,
        [int] $vusers,
        [bool]$verbose = $False
    )

    $result = @"
    {
        "testId": "$testId",
        "testRunId": "$testRunId",
        "displayName": "$testRunName",
        "description": "$testRunDescription",
        "vusers": $vusers
    }
"@

    return $result
}

$testRunId = (New-Guid).toString()
$urlRoot = "$apiEndpoint/testruns/$testRunId"

# Prep load test run body
$testRunData = GetTestRunBody -testId $loadTestId `
    -testRunName $testRunName `
    -testRunDescription $testRunDescription `
    -testRunId $testRunId `
    -vusers $testRunVUsers

# Following is to get Invoke-RestMethod to work
$url = $urlRoot + "?api-version=" + $apiVersion + "&tenantId=" + $tenantId

$header = @{
    'Content-Type'='application/merge-patch+json'
    'testRunId'="$testRunId"
}

# Secure string to use access token with Invoke-RestMethod in Powershell
$accessTokenSecure = ConvertTo-SecureString -String $accessToken -AsPlainText -Force

$result = Invoke-RestMethod `
    -Uri $url `
    -Method PATCH `
    -Authentication Bearer `
    -Token $accessTokenSecure `
    -Body $testRunData `
    -Headers $header `
    -Verbose:$verbose

echo $result

# Outputs and exports for pipeline usage
if($pipeline) {
    $testRunId = ($result).testRunId
    echo "##vso[task.setvariable variable=testRunId]$testRunId" # contains the testRunId for in-pipeline usage
  }

Remove-Item $accessTokenFileName
