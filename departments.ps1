$config = ConvertFrom-Json $configuration;

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12; 
function get_oauth_access_token {
[cmdletbinding()]
Param (
[string]$BaseURI,
[string]$ClientKey,
[string]$ClientSecret
   )
    Process
    {
        $pair = $ClientKey + ":" + $ClientSecret;
        $bytes = [System.Text.Encoding]::ASCII.GetBytes($pair);
        $bear_token = [System.Convert]::ToBase64String($bytes);
        $auth_headers = @{ Authorization = "Basic " + $bear_token };
        
        $uri =  "$($BaseURI)/oauth/token?grant_type=client_credentials";
        $result = Invoke-RestMethod -Method GET -Headers $auth_headers -Uri $uri -UseBasicParsing;
        @($result);
    }
}
function get_data_objects {
[cmdletbinding()]
Param (
[string]$ModuleName,
[string]$ObjectName,
[array]$SearchFields
   )
    Process
    {
         
        #######ACCESS TOKEN##########
        Write-Host (Get-Date) "Retrieving Access Token";
         
        $AccessToken = (get_oauth_access_token `
            -BaseURI $config.BaseURI `
            -ClientKey $config.ClientKey `
            -ClientSecret $config.ClientSecret).access_token
         
        $headers = @{ Authorization = "Bearer $($AccessToken)" };
 
        #####GET DATA########
        Write-Verbose -Verbose "Getting Data Objects for ( $($ModuleName) : $($ObjectName) )";
        Write-Verbose -Verbose "Search Fields: $($SearchFields)";
        $result = [System.Collections.ArrayList]@();
        $object_uri = "$($config.BaseURI)/Generic/$($config.EntityId)/$($ModuleName)/$($ObjectName)";
        $page_uri = "$($object_uri)/1/$($config.PageSize)";
        $request_params = @{};
 
        #--SCHOOL YEAR--#
        if($config.SchoolYearId.Length -gt 0)
        {
            $request_params['SchoolYearID'] = "$($config.SchoolYearId)";
            Write-Verbose -Verbose "Enforcing SchoolYearID $($config.SchoolYearId)";
        }
 
        #--FISCAL YEAR--#
        if($config.FiscalYearId.Length -gt 0)
        {
            $request_params['FiscalYearID'] = "$($config.FiscalYearId)";
            Write-Verbose -Verbose "Enforcing FiscalYearID $($config.FiscalYearId)";
        }
 
        #--SEARCH FIELDS--#                
        if($SearchFields.Length -gt 0)
        {
            $i = 0
            foreach ($field in $SearchFields)
            {
                $request_params["searchFields[$($i)]"] = "$($field)";
                $i++;
            }
        }
         
        $page_result = $null;
        $page_result = Invoke-RestMethod -Method GET -Uri $page_uri -body $request_params -Headers $headers -UseBasicParsing;
         
        $previous_page_uri = $page_uri;
        $next_page_uri = "$($config.BaseURI)$($page_result.Paging.Next)";

        if($page_result.Objects.Count -eq 0)
        {
            Write-Verbose -Verbose "1 Record returned"
            $result.Add($page_result);
        }
        else
        {
            Write-Verbose -Verbose "$($page_result.Objects.Count) Record(s) returned"
            $result.AddRange($page_result.Objects);
 
            while($next_page_uri -ne $config.BaseURI -and $next_page_uri -ne $previous_page_uri)
            {
                $next_page_uri = "$($next_page_uri)";
                Write-Verbose -Verbose "$next_page_uri";
                $page_result = $null;
                $page_result = Invoke-RestMethod -Method GET -Uri $next_page_uri -Body $request_params -Headers $headers -UseBasicParsing
             
                $previous_page_uri = $next_page_uri;
                $next_page_uri = "$($config.BaseURI)$($page_result.Paging.Next)";
             
                Write-Verbose -Verbose  "$($page_result.Objects.Count) Record(s) returned"
                $result.AddRange($page_result.Objects);
            }
        }
         
        Remove-Variable -Name "SearchFields" -ErrorAction SilentlyContinue
         
        Write-Verbose -Verbose "Total of $($result.Count) Record(s) returned"                
        @($result);
    }
}
 
try{
$Entity = get_data_objects `
        -ModuleName "District" `
        -ObjectName "Entity" `
        -SearchFields @( ("EntityID,Code,CodeName,Name") -split ",")
 
foreach($e in $entity)
{
    $row = @{
              ExternalId = $e.EntityID;
              DisplayName = $e.Name;
              Code = $e.Code
              CodeName = $e.CodeName;
    }
 
    $row | ConvertTo-Json -Depth 10
}
 
}catch
{
    throw $_;
}
