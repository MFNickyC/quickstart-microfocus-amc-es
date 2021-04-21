[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)] [string]$Namespace
)

$LogFilePath = "c:\cfn\log\Cloudwatch-Metrics-Pusher-Log.txt"

$Date = Get-Date
Add-Content -Path $LogFilePath -Value "${Date}: CloudWatch Metrics Pusher Started"

#Logon to ESCWA
$JMessage = '{ \"mfUser\": \"\", \"mfPassword\": \"\" }'
$RequestURL = 'http://localhost:10004/logon'
$Origin = 'Origin: http://localhost:10004'
curl.exe -sX POST  $RequestURL -H 'accept: application/json' -H 'X-Requested-With: AgileDev' -H 'Content-Type: application/json' -H $Origin -d $Jmessage --cookie-jar cookie.txt | Out-Null

function MakeRequest {
    param (
        [Parameter(Mandatory = $true)][string] $RequestURL
    )
    $headers = @{
        'accept' = 'application/json'
        'Content-Type' = 'application/json'
        'X-Requested-With' = 'AgileDev'
        'Origin' = 'http://localhost:10004'
    }

    $Response = Invoke-RestMethod -URI $RequestURL -headers $headers -method 'GET'
    return $Response
}

# Get SOR UID
Add-Content -Path $LogFilePath -Value "Get SOR UID"
$RequestURL = 'http://localhost:10004/server/v1/config/groups/sors'
$Response = MakeRequest -RequestURL $RequestURL
$SORUid = $Response[0].Uid
Add-Content -Path $LogFilePath -Value "SOR UID: ${SORUid}"

# Get the AWS Region
$AWSRegion = curl.exe -s http://169.254.169.254/latest/meta-data/placement/region

for (;;) {
    $NumberOfRunningRegions = 0
    $TotalTransactionsPerHour = 0
    $TotalTasksPerSecond = 0
    $TotalTaskLatencyInMs = 0
    $TotalTaskDurationInMs = 0

    # Get PAC regions
    $RequestURL =  "http://localhost:10004/server/v1/config/groups/sors/${SORUid}/pac"
    $Response = MakeRequest -RequestURL $RequestURL
    $Regions = $Response.Regions

    # Get metrics from each region
    foreach ($Region in $Regions) {
        try {
            # Get metrics
            $RequestURL = "http://localhost:10004/native/v1/regions/$($Region.Host)/$($Region.Port)/$($Region.CN)/esproperties"
            $Response = MakeRequest -RequestURL $RequestURL

            $TotalTransactionsPerHour += [int]$Response.PerHourCount
            $TotalTasksPerSecond += [double]$Response.CR
            $TotalTaskLatencyInMs +=[int]$Response.CP.Split(";")[0]
            $TotalTaskDurationInMs += [int]$Response.CP.Split(";")[1]
            $NumberOfRunningRegions++
        }
        catch {
            # Request timed out / failed
        }
    }

    if ($NumberOfRunningRegions -gt 0) {
        # Push the metrics to CloudWatch
        $AvgTransactionsPerHour = $TotalTransactionsPerHour / $NumberOfRunningRegions
        $AvgTasksPerSecond = $TotalTasksPerSecond / $NumberOfRunningRegions
        $AvgTaskLatencyInMs = $TotalTaskLatencyInMs / $NumberOfRunningRegions
        $AvgTaskDurationInMs = $TotalTaskDurationInMs / $NumberOfRunningRegions

        $Date = Get-Date
        $Msg = ("${Date}: Average transactions per hour: $AvgTransactionsPerHour, Average tasks per second: $AvgTasksPerSecond" +
                ", Average task latency (ms): $AvgTaskLatencyInMs, Average task duration (ms) $AvgTaskDurationInMs")
        Add-Content -Path $LogFilePath -Value $Msg

        aws cloudwatch put-metric-data --metric-name avg-transactions-per-hour --namespace $Namespace --value $AvgTransactionsPerHour --region $AWSRegion
	    aws cloudwatch put-metric-data --metric-name avg-tasks-per-second --namespace $Namespace --value $AvgTasksPerSecond --region $AWSRegion
        aws cloudwatch put-metric-data --metric-name avg-task-latency-in-ms --namespace $Namespace --value $AvgTaskLatencyInMs --region $AWSRegion
        aws cloudwatch put-metric-data --metric-name avg-task-duration-in-ms --namespace $Namespace --value $AvgTaskDurationInMs --region $AWSRegion
    }

    Start-Sleep 30
}
