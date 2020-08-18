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
$Students = get_data_objects `
        -ModuleName "Student" `
        -ObjectName "Student" `
        -SearchFields ( ("StudentID,HasStudentEntityYearForCurrentSchoolYear,CalculatedEntityYearIsActive,CalculatedGrade,CalculatedGradYear,CurrentDefaultEntityIsActive,FirstName,FullNameFL,FullNameFML,FullNameLFM,Grade,GradeNumeric,GradYear,IsActiveAsOfDate,IsCurrentActive,IsGraduated,LastName,MaskedStudentNumber,MiddleName,NameID,StudentNumber") -split ",")
 
$Demographics = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "Name" `
        -SearchFields ( ("NameID,Age,BirthDate,Gender,GenderCode,FirstName,LastName,MiddleName") -split ",")
         
$StudentEntityYear = get_data_objects `
        -ModuleName "Enrollment" `
        -ObjectName "StudentEntityYear" `
        -SearchFields ( ("EntityID,FirstName,HomeroomID,IsActive,IsDefaultEntity,LastName,MiddleName,NameID,SchoolYearID,StaffIDAdvisor,StudentID") -split ",")
 
$SchoolYear = get_data_objects `
        -ModuleName "District" `
        -ObjectName "SchoolYear" `
        -SearchFields @( ("SchoolYearID,Description,IsCurrentYearForProvidedEntity,NumericYear,NextNumericYear") -split ",")
 
$Email = get_data_objects `
        -ModuleName "Demographics" `
        -ObjectName "NameEmail" `
        -SearchFields @( ("NameEmailID,EmailAddress,EmailTypeID,NameID,Rank") -split ",")  
 
$SchoolYear = get_data_objects `
        -ModuleName "District" `
        -ObjectName "SchoolYear" `
        -SearchFields @( ("SchoolYearID,Description,IsCurrentYearForProvidedEntity,NumericYear,NextNumericYear") -split ",")
 
 
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
 
foreach($student in $students)
{
    $person = @{};
    $person["ExternalId"] = $student.NameID;
    $person["DisplayName"] = "$($student.FullNameFL)"
    $person["Role"] = "Student"
     
    foreach($prop in $student.PSObject.properties)
    {
        $person[$prop.Name] = "$($prop.Value)";
    }
     
    foreach($demo in $demographics)
    {
        if($demo.NameID -eq $student.NameID)
        {
            $person["demographic"] = $demo;
            break;
        }
    }
 
    $person["Emails"] = [System.Collections.ArrayList]@();
    foreach($em in $Email)
    {
        if($em.NameID -eq $student.NameID)
        {
            [void]$person["Emails"].Add($em);
        }
    }
 
    $person["Contracts"] = [System.Collections.ArrayList]@();
 
    foreach($entity in $StudentEntityYear)
    {
         
        if($entity.NameID -eq $student.NameID)
        {
            $contract = @{};
 
            if($entity.IsDefaultEntity -eq "True")
            {
                $person["DefaultEntity"] = $entity.EntityID;
            }
 
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
 
    Write-Output ($person | ConvertTo-Json -Depth 20);
}
 
 
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
}catch
{
    throw $_;
}