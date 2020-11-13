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
   
  $Staff = get_data_objects `
          -ModuleName "Staff" `
          -ObjectName "Staff" `
          -SearchFields @( ("StaffID,DistrictID,FullNameFL,FullNameFML,FullNameLFM,IsActiveForDistrict,IsCurrentStaffEntityYear,NameID,StaffNumber") -split ",") 
   
  $StaffEntityYear = get_data_objects `
          -ModuleName "Staff" `
          -ObjectName "StaffEntityYear" `
          -SearchFields ( ("EntityID,IsCareerCenterCounselor,IsDisciplineOfficer,IsSubstituteTeacher,IsTeacher,SchoolYearID,StaffEntityYearID,StaffID,TeacherNumber") -split ",")
   
  $StaffStaffType = get_data_objects `
          -ModuleName "Staff" `
          -ObjectName "StaffStaffType" `
          -SearchFields ( ("EndDate,IsPrimary,PositionDescription,StaffID,StaffStaffTypeID,StaffTypeID,StartDate") -split ",")
   
  $StaffTypes = get_data_objects `
          -ModuleName "Staff" `
          -ObjectName "StaffType" `
          -SearchFields ( ("Code,CodeDescription,Description,StaffTypeID") -split ",")

  $Demographics = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "Name" `
        -SearchFields ( ("NameID,Age,BirthDate,Gender,GenderCode,FirstName,LastName,MiddleName") -split ",")

foreach($stf in $staff)
{
    $person = @{};
    $person["ExternalId"] = $stf.NameID;
    $person["DisplayName"] = "$($stf.FullNameFL)"
    $person["Role"] = "Employee"
    
    foreach($prop in $stf.PSObject.properties)
    {
        $person[$prop.Name] = "$($prop.Value)";
    }
    
    foreach($demo in $demographics)
    {
        if($demo.NameID -eq $stf.NameID)
        {
            $person["demographic"] = $demo;
            break;
        }
    }
    $person["Emails"] = [System.Collections.ArrayList]@();
    foreach($em in $Email)
    {
        if($em.NameID -eq $stf.NameID)
        {
            [void]$person["Emails"].Add($em);
        }
    }
    
    $person["Contracts"] = [System.Collections.ArrayList]@();
    foreach($entity in $StaffEntityYear)
    {
        if($entity.StaffID -eq $stf.StaffID)
        {
            $contract = @{};
            foreach($prop in $entity.PSObject.properties)
            {
                $contract[$prop.Name] = "$($prop.Value)";
            }

            foreach($year in $SchoolYear)
            {
                if($year.SchoolYearID -eq $entity.SchoolYearID)
                {
                    $contract["schoolYear"] = $year;
                    break;
                }
            }
            [void]$person.Contracts.Add($contract);
        }
    }
    
    $person["Types"] = [System.Collections.ArrayList]@();
    foreach($ssType in $StaffStaffType)
    {
        if($ssType.StaffID -eq $stf.StaffID)
        {
            $types = @{};
            foreach($prop in $ssType.PSObject.properties)
            {
                $types[$prop.Name] = "$($prop.Value)";
            }

            foreach($stype in $StaffTypes)
            {
                
                if($stype.StaffTypeID -eq $ssType.StaffTypeID)
                {
                    $types["staffType"] = $stype;
                    
                    if($ssType.IsPrimary -eq $True)
                    {
                        $person["PrimaryStaffTypeCode"] = $stype.Code;
                    }
                    break;
                }
            }
            [void]$person.Types.Add($types);
        }
    }
    
    Write-Output ($person | ConvertTo-Json -Depth 20);
}
}
catch
{
    Write-Error -Verbose $_;
    throw $_;   
}
