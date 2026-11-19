**Free
//==============================================================================
// Program:     GETWEATHER.SQLRPGLE
// Programmer:  Chris Grimm
// Date:        11/19/2026
//
// Description:
//     Reusable REST API program that retrieves current weather metrics from
//     OpenWeatherMap using DB2 HTTP functions (QSYS2.HTTP_GET) and JSON_TABLE.
//     Accepts city and optional country code inputs, selects imperial or
//     metric units based on country code, parses the JSON payload into a
//     qualified data structure (weather_t), and returns the results along
//     with a success indicator to the calling program.
//
// Endpoint:    api.openweathermap.org/data/2.5/weather (HTTPS / JSON)
// Parameters:  pCity, pCountry (In) | pData, pSuccess (Out)
//
// Maintenance Log:
// Date        Author       Description
// ----------  -----------  ----------------------------------------------------
// 11/19/2026  Chris Grimm  Initial program creation.
//==============================================================================

Ctl-Opt DftActGrp(*No) ActGrp(*Caller) Option(*SrcStmt: *NoDebugIO);

// Weather data structure template
Dcl-Ds weather_t Qualified Template;
  temp        Packed(5:2);
  feelsLike   Packed(5:2);
  tempMin     Packed(5:2);
  tempMax     Packed(5:2);
  humidity    Int(10);
  pressure    Int(10);
  condition   VarChar(30);
  description VarChar(60);
  windSpeed   Packed(5:2);
  windDeg     Int(10);
  clouds      Int(10);
  visibility  Int(10);
  tempUnit    Char(1);
  speedUnit   VarChar(3);
End-Ds;

// Main program parameter interface
Dcl-Pi GETWEATHER;
  // Inputs
  pCity        VarChar(100) Const Options(*Trim);
  pCountry     VarChar(2)   Const Options(*NoPass: *Trim);

  // Outputs
  pData        LikeDs(weather_t)  Options(*NoPass);
  pSuccess     Ind                Options(*NoPass);
End-Pi;

// Working storage variables
Dcl-S url          VarChar(500);
Dcl-S apiKey       VarChar(50) Inz('YOUR_OPENWEATHERMAP_API_KEY');
Dcl-S location     VarChar(103);
Dcl-S units        VarChar(10);
Dcl-S upperCountry Char(2);
Dcl-Ds weatherData LikeDs(weather_t);

// Determine unit system based on country code (US, LR, MM = Standard/Imperial)
If %Parms() >= 2 And %Addr(pCountry) <> *Null And pCountry <> *Blanks;
  upperCountry = %Upper(%Trim(pCountry));
  location     = %Trim(pCity) + ',' + %Trim(upperCountry);

  If upperCountry = 'US' Or upperCountry = 'LR' Or upperCountry = 'MM';
    units                 = 'imperial';
    weatherData.tempUnit  = 'F';
    weatherData.speedUnit = 'mph';
  Else;
    units                 = 'metric';
    weatherData.tempUnit  = 'C';
    weatherData.speedUnit = 'm/s';
  EndIf;
Else;
  location              = %Trim(pCity);
  units                 = 'metric';
  weatherData.tempUnit  = 'C';
  weatherData.speedUnit = 'm/s';
EndIf;

// Construct endpoint URL
url = 'https://api.openweathermap.org/data/2.5/weather?q=' +
      %ScanRpl(' ': '%20': %Trim(location)) +
      '&units=' + %Trim(units) +
      '&APPID=' + %Trim(apiKey);

// Query API via SQL HTTP functions
Exec Sql
  Select Coalesce(api_temp, 0),
         Coalesce(api_feels_like, 0),
         Coalesce(api_temp_min, 0),
         Coalesce(api_temp_max, 0),
         Coalesce(api_humidity, 0),
         Coalesce(api_pressure, 0),
         Coalesce(api_condition, ''),
         Coalesce(api_description, ''),
         Coalesce(api_wind_speed, 0),
         Coalesce(api_wind_deg, 0),
         Coalesce(api_clouds, 0),
         Coalesce(api_visibility, 0)
    Into :weatherData.temp,
         :weatherData.feelsLike,
         :weatherData.tempMin,
         :weatherData.tempMax,
         :weatherData.humidity,
         :weatherData.pressure,
         :weatherData.condition,
         :weatherData.description,
         :weatherData.windSpeed,
         :weatherData.windDeg,
         :weatherData.clouds,
         :weatherData.visibility
  From Json_Table(
    QSYS2.HTTP_GET(:url, ''),
    '$' Columns(
      api_temp        Double
        Path '$.main.temp'
        Default 0 On Empty Default 0 On Error,
      api_feels_like  Double
        Path '$.main.feels_like'
        Default 0 On Empty Default 0 On Error,
      api_temp_min    Double
        Path '$.main.temp_min'
        Default 0 On Empty Default 0 On Error,
      api_temp_max    Double
        Path '$.main.temp_max'
        Default 0 On Empty Default 0 On Error,
      api_humidity    Integer
        Path '$.main.humidity'
        Default 0 On Empty Default 0 On Error,
      api_pressure    Integer
        Path '$.main.pressure'
        Default 0 On Empty Default 0 On Error,
      api_condition   VarChar(30)
        Path '$.weather[0].main'
        Default '' On Empty Default '' On Error,
      api_description VarChar(60)
        Path '$.weather[0].description'
        Default '' On Empty Default '' On Error,
      api_wind_speed  Double
        Path '$.wind.speed'
        Default 0 On Empty Default 0 On Error,
      api_wind_deg    Integer
        Path '$.wind.deg'
        Default 0 On Empty Default 0 On Error,
      api_clouds      Integer
        Path '$.clouds.all'
        Default 0 On Empty Default 0 On Error,
      api_visibility  Integer
        Path '$.visibility'
        Default 0 On Empty Default 0 On Error
    )
  );

// Pass output values back to caller
If %Parms() >= 3 And %Addr(pData) <> *Null;
  pData = weatherData;
EndIf;

If %Parms() >= 4 And %Addr(pSuccess) <> *Null;
  pSuccess = (sqlcode = 0);
EndIf;

*Inlr = *On;
Return;
