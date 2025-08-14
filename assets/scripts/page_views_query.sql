SELECT 
     Name AS PageName,  
     Url AS url, 
     UserAuthenticatedId AS JhedId, 
     OperationName,
     time AS EventDateTime,
     ClientType AS deviceId,
     ClientType AS deviceType,
     ClientOS AS osVersion,
     ClientBrowser AS browser,
     ClientBrowser AS browserVersion,
     ClientCountryOrRegion AS country,
     ClientStateOrProvince AS province,
     ClientCity AS city,
     Properties AS Context
INTO ${output_alias}
FROM ${input_alias}
