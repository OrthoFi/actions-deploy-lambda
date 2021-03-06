[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [String]$Command,
    [Parameter(Mandatory = $true)]
    [String]$Domain,
    [Parameter(Mandatory = $true)]
    [String]$FunctionName,
    [Parameter(Mandatory = $false)]
    [String]$ImageName,
    [Parameter(Mandatory = $true)]
    [String]$Sha
)

function Wait-For-Ready {
    do {
        Start-Sleep 5
        $function = ConvertFrom-Json($($(aws lambda get-function --function-name $FunctionName) -join ''))
        if ($function.Configuration.LastUpdateStatus -eq "InProgress") {
            Write-Host "Function update is still in progress"
        }
        else {
            Write-Host "Last Update Status: $($function.Configuration.LastUpdateStatus)"
        }
    } while ($function.Configuration.LastUpdateStatus -eq "InProgress")
}

$number = $(ConvertFrom-Json((aws sts get-caller-identity) -join '')).Account
if ($ImageName) {
    $uri = "${number}.dkr.ecr.us-east-1.amazonaws.com/${ImageName}:sha-$Sha"
}
else {
    $uri = "${number}.dkr.ecr.us-east-1.amazonaws.com/$Domain-lambda:sha-$Sha"
}

aws lambda update-function-code --function-name $FunctionName --image-uri $uri

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Wait-For-Ready

aws lambda update-function-configuration --function-name $FunctionName --image-config Command=$Command

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Wait-For-Ready

aws lambda tag-resource --resource "arn:aws:lambda:us-east-1:${number}:function:$FunctionName" --tags "version=sha-$Sha"