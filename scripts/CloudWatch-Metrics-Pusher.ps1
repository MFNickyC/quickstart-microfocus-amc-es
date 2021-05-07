[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)] [string]$Namespace
)

$LOGFILEPATH = "c:\cfn\log\Cloudwatch-Metrics-Pusher-Log.txt"
$HEADERS = @{
    'accept' = 'application/json'
    'Content-Type' = 'application/json'
    'X-Requested-With' = 'AgileDev'
    'Origin' = 'http://localhost:10086'
}

$Date = Get-Date
Add-Content -Path $LOGFILEPATH -Value "${Date}: CloudWatch Metrics Pusher Started"

# Get the AWS Region
$AWSRegion = curl.exe -s http://169.254.169.254/latest/meta-data/placement/region

for (;;) {
    $NumberOfRunningRegions = 0
    $TotalTransactionsPerHour = 0
    $TotalTasksPerSecond = 0
    $TotalTaskLatencyInMs = 0
    $TotalTaskDurationInMs = 0

    # Logon to ESCWA
    $Body = @{
        'mfUser'= ''
        'mfPassword' = ''
    }
    $RequestURL = 'http://localhost:10086/logon'
    Invoke-WebRequest $RequestURL -SessionVariable 'Session' -Headers $HEADERS -Body ($Body|ConvertTo-Json) -Method 'POST'

    # Get SOR UID
    Add-Content -Path $LOGFILEPATH -Value "Get SOR UID"
    $RequestURL = 'http://localhost:10086/server/v1/config/groups/sors'
    $Response = Invoke-RestMethod -URI $RequestURL -Headers $HEADERS -WebSession $Session -Method 'GET'
    $SORUid = $Response[0].Uid
    Add-Content -Path $LOGFILEPATH -Value "SOR UID: ${SORUid}"

    # Get PAC regions
    $RequestURL =  "http://localhost:10086/server/v1/config/groups/sors/${SORUid}/pac"
    $Response = Invoke-RestMethod -URI $RequestURL -Headers $HEADERS -WebSession $Session -Method 'GET'
    $Regions = $Response.Regions

    # Get metrics from each region
    foreach ($Region in $Regions) {
        try {
            # Get metrics
            $RequestURL = "http://localhost:10086/native/v1/regions/$($Region.Host)/$($Region.Port)/$($Region.CN)/esproperties"
            $Response = Invoke-RestMethod -URI $RequestURL -Headers $HEADERS -WebSession $Session -Method 'GET' -TimeoutSec 2

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
        Add-Content -Path $LOGFILEPATH -Value $Msg

        aws cloudwatch put-metric-data --metric-name avg-transactions-per-hour --namespace $Namespace --value $AvgTransactionsPerHour --region $AWSRegion
	    aws cloudwatch put-metric-data --metric-name avg-tasks-per-second --namespace $Namespace --value $AvgTasksPerSecond --region $AWSRegion
        aws cloudwatch put-metric-data --metric-name avg-task-latency-in-ms --namespace $Namespace --value $AvgTaskLatencyInMs --region $AWSRegion
        aws cloudwatch put-metric-data --metric-name avg-task-duration-in-ms --namespace $Namespace --value $AvgTaskDurationInMs --region $AWSRegion
    }

    # Logout of ESCWA
    $RequestURL = 'http://localhost:10086/logoff'
    Invoke-RestMethod -URI $RequestURL -Headers $HEADERS -WebSession $Session -Method 'DELETE'

    Start-Sleep 30
}
