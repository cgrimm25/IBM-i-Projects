**Free
//==============================================================================
// Program:     TESTWEATH.RPGLE
// Programmer:  Chris Grimm
// Date:        11/19/2026
//
// Description:
//     Interactive weather inquiry program utilizing a display file (WEATHDSPF).
//     Prompts user for a City/State and optional Country code, calls the
//     GETWEATHER external program to fetch live metrics, and populates the
//     screen fields and unit labels. Supports F3 to exit and F5 to clear.
//
// Calls:       GETWEATHER (External SQLRPGLE Program)
//
// Maintenance Log:
// Date        Author       Description
// ----------  -----------  ----------------------------------------------------
// 11/19/2026  Chris Grimm  Initial program creation.
//==============================================================================

Ctl-Opt DftActGrp(*No) ActGrp(*New) Option(*SrcStmt: *NoDebugIO);

// Display file declaration
Dcl-F WEATHDSPF WorkStn;

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

// Prototype defining GETWEATHER's interface
Dcl-Pr GETWEATHER ExtPgm('GETWEATHER');
  pCity        VarChar(100) Const Options(*Trim);
  pCountry     VarChar(2)   Const Options(*NoPass: *Trim);
  pData        LikeDs(weather_t)  Options(*NoPass);
  pSuccess     Ind                Options(*NoPass);
End-Pr;

// Working storage variables
Dcl-Ds weatherInfo LikeDs(weather_t);
Dcl-S  isSuccess   Ind;

// Initialize default location
SCNCITY = 'Grand Rapids, MI';
SCNCTRY = 'US';

// Main interactive screen loop
DoU *In03;
  ExFmt WEATHSCN;

  // Reset error highlight and message
  *In50  = *Off;
  SCNMSG = *Blanks;

  // F3 = Exit
  If *In03;
    Leave;
  EndIf;

  // F5 = Clear all fields
  If *In05;
    Clear WEATHSCN;
    Iter;
  EndIf;

  // Validate required city input
  If %Trim(SCNCITY) = *Blanks;
    *In50  = *On;
    SCNMSG = 'Please enter a City or City,State before pressing Enter.';
    Iter;
  EndIf;

  // Call GETWEATHER REST API program
  GETWEATHER(%Trim(SCNCITY): %Trim(SCNCTRY): weatherInfo: isSuccess);

  If isSuccess;
    SCNCOND   = weatherInfo.condition;
    SCNDESC   = weatherInfo.description;
    SCNTEMP   = weatherInfo.temp;
    SCNFEELS  = weatherInfo.feelsLike;
    SCNTMIN   = weatherInfo.tempMin;
    SCNTMAX   = weatherInfo.tempMax;
    SCNTUNIT1 = weatherInfo.tempUnit;
    SCNTUNIT2 = weatherInfo.tempUnit;
    SCNTUNIT3 = weatherInfo.tempUnit;
    SCNTUNIT4 = weatherInfo.tempUnit;
    SCNHUM    = weatherInfo.humidity;
    SCNPRESS  = weatherInfo.pressure;
    SCNWSPEED = weatherInfo.windSpeed;
    SCNWUNIT  = weatherInfo.speedUnit;
    SCNWDEG   = weatherInfo.windDeg;
    SCNCLOUDS = weatherInfo.clouds;
    SCNVIS    = weatherInfo.visibility;
  Else;
    Clear SCNCOND;
    Clear SCNDESC;
    Clear SCNTMIN;
    Clear SCNTMAX;
    Clear SCNTEMP;
    Clear SCNFEELS;
    Clear SCNTUNIT1;
    Clear SCNTUNIT2;
    Clear SCNTUNIT3;
    Clear SCNTUNIT4;
    Clear SCNHUM;
    Clear SCNPRESS;
    Clear SCNWSPEED;
    Clear SCNWUNIT;
    Clear SCNWDEG;
    Clear SCNCLOUDS;
    Clear SCNVIS;
    *In50  = *On;
    SCNMSG = 'Weather lookup failed. Verify City/State and Country Code.';
  EndIf;
EndDo;

*Inlr = *On;
Return;
