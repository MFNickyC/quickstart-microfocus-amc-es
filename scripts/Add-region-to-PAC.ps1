try {
    $ErrorActionPreference = "Stop"
    Start-Transcript -Path c:\cfn\log\$($MyInvocation.MyCommand.Name).txt -Append -IncludeInvocationHeader;
    Write-Host "Configuring ESCWA"

    # Logon to ESCWA
    $JMessage = '{ \"mfUser\": \"\", \"mfPassword\": \"\" }'

    $RequestURL = 'http://localhost:10086/logon'
    $Origin = 'Origin: http://localhost:10086'

    curl.exe -sX POST  $RequestURL -H 'accept: application/json' -H 'X-Requested-With: AgileDev' -H 'Content-Type: application/json' -H $Origin -d $Jmessage --cookie-jar cookie.txt | Out-Null

    # Add PAC configuration to region
    Write-Host "Adding to PAC"
    $RequestURL = 'http://localhost:10086/native/v1/regions/127.0.0.1/86/BNKDM'
    $JMessage = '
        {
            \"mfCASSOR\": \"' + ":ES_SCALE_OUT_REPOS_1=DemoPSOR=redis,ESRedis:6379##TMP" + '\",
            \"mfCASPAC\": \"' + "DemoPAC" + '\",
        }'
    curl.exe -sX PUT $RequestURL -H 'accept: application/json' -H 'X-Requested-With: AgileDev' -H 'Content-Type: application/json' -H $Origin -d $Jmessage --cookie-jar cookie.txt | Out-Null
}
catch {
    $_ | Write-AWSQuickStartException
}