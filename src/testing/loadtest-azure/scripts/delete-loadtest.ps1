param
(
  # Load Test Id
  [string] $loadTestId,
  # Load Test data plane endpoint
  [string] $apiEndpoint,
  # Load Test data plane api version
  [string] $apiVersion
)

if (!$loadTestId) {
  throw "ERROR - Parameter loadTestId is required and cannot be empty."
}

. ./common.ps1

$urlRoot = $apiEndpoint + "/loadtests/" + "$loadTestId"

az rest --url $urlRoot `
  --method DELETE `
  --skip-authorization-header `
  --headers "$accessTokenHeader" `
  --url-parameters testId="$loadTestId" api-version="$apiVersion" `
  $verbose
