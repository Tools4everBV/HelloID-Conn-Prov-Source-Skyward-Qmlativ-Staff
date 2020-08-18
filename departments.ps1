## Settings ##
[string]$global:config_BaseURI = "https://skyward.iscorp.com/<CUSTOMER NAME>";
[string]$global:config_ClientKey = "KEY";
[string]$global:config_ClientSecret = "SECRET";
[string]$global:config_PageSize = "500";
[string]$global:config_EntityId = "2";
[string]$global:config_SchoolYearId = "2";
[string]$global:config_FiscalYearId = "";
 
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
 
        $uri =  "$BaseURI/oauth/token?grant_type=client_credentials";
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
            -BaseURI $config_BaseURI `
            -ClientKey $config_ClientKey `
            -ClientSecret $config_ClientSecret).access_token
         
        $headers = @{ Authorization = "Bearer " + $AccessToken };
 
 
        #####GET DATA########
        Write-Host (Get-Date) "Getting Data Objects for ( $ModuleName : $ObjectName )";
        Write-Host (Get-Date) "Search Fields: $SearchFields";
        $result = @();
        $object_uri = "$config_BaseURI/Generic/$config_EntityId/$ModuleName/$ObjectName";
        $page_uri = "$object_uri/1/$config_PageSize";
                     
        $query_params = @();
        $uri_params = "";
 
        #--SCHOOL YEAR--#
        if($config_SchoolYearId.Length -gt 0)
        {
            $query_params = $query_params + "SchoolYearID=$config_SchoolYearId";
            Write-Host (Get-Date) "Enforcing SchoolYearID $config_SchoolYearId";
        }
 
        #--FISCAL YEAR--#
        if($config_FiscalYearId.Length -gt 0)
        {
            $query_params = $query_params + "FiscalYearID=$config_FiscalYearId";
            Write-Host (Get-Date) "Enforcing FiscalYearID $config_FiscalYearId";
        }
 
        #--SEARCH FIELDS--#                
        if($SearchFields.Length -gt 0)
        {
            $i = 0
            foreach ($field in $SearchFields)
            {
                $query_params = $query_params + "searchFields[$i]=$field";
                $i++;
            }
                     
        }
         
        if($query_params.count -gt 0)
        {
            $i = 0;
            foreach ($param in $query_params)
            {
                if($i -eq 0)
                {
                    $uri_params = $uri_params + "?$param";
                }
                else
                {
                    $uri_params = $uri_params + "&$param";
                }
                $i++;
            }
        }
             
        $page_uri = $page_uri + $uri_params;
        #Write-Host (Get-Date) " - $page_uri";
        $page_result = $null;
        $page_result = Invoke-RestMethod -Method GET -Uri $page_uri -Headers $headers -Timeout 3600 -UseBasicParsing;
         
        $previous_page_uri = $page_uri;
        $next_page_uri = "$config_BaseURI" + $page_result.Paging.Next
 
        if($page_result.Objects.Count -eq 0)
        {
            Write-Host (Get-Date) " 1 Record returned"
            $result += $page_result;
        }
        else
        {
            Write-Host (Get-Date) ($page_result.Objects.Count) " Records returned"
            $result += $page_result.Objects;
 
            while($next_page_uri -ne $config_BaseURI -and $next_page_uri -ne $previous_page_uri)
            {
                $next_page_uri = $next_page_uri + $uri_params;
                #Write-Host (Get-Date) " - $next_page_uri";
                $page_result = $null;
                $page_result = Invoke-RestMethod -Method GET -Uri $next_page_uri -Headers $headers -Timeout 3600 -UseBasicParsing
             
                $previous_page_uri = $next_page_uri;
                $next_page_uri = "$config_BaseURI" + $page_result.Paging.Next
             
                Write-Host (Get-Date) ($page_result.Objects.Count) " Records returned"
                $result += $page_result.Objects;
            }
        }
         
        Remove-Variable -Name "SearchFields" -ErrorAction SilentlyContinue
         
        Write-Host (Get-Date) ($result.Count) " Total Records returned"                
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