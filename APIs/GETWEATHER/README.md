# IBM i Current Weather Lookup (`GETWEATHER`)

An interactive IBM i weather lookup utility built with free-form RPGLE, embedded SQL (`SQLRPGLE`), and a DDS Display File (`DSPF`). The application separates data retrieval from the user interface by calling a reusable REST API service program that queries the OpenWeatherMap API via DB2 HTTP functions (`QSYS2.HTTP_GET`) and parses the JSON response with `JSON_TABLE`.

## Screenshots

### US Lookup (Imperial Units)
![Grand Rapids, MI - Imperial Output](Images/weather-us-imperial.png)

### International Lookup (Metric Units)
![Rome, IT - Metric Output](Images/weather-it-metric.png)

## Architecture & Source Files

| File | Type | Description |
| :--- | :--- | :--- |
| **`GETWEATHER.SQLRPGLE`** | SQLRPGLE | Reusable program that accepts a city and optional country code, encodes spaces for URL safety, queries OpenWeatherMap, and returns a populated `weather_t` data structure and success indicator. |
| **`TESTWEATH.RPGLE`** | RPGLE | Interactive front-end program that manages the `WEATHDSPF` display loop, validates user input, calls `GETWEATHER`, and maps the returned metrics and unit labels to the screen. |
| **`WEATHDSPF.DSPF`** | DSPF | 5250 Display File (`27x132 *DS4`) featuring mixed-case city input (`CHECK(LC)`), dynamic unit labels, reverse-image error messaging, and `F3=Exit` / `F5=Clear` function keys. |

## Key Features

* **Modular Program-to-Program Design:** `GETWEATHER` is decoupled from the UI and returns all 14 weather metrics and unit labels through a qualified `weather_t` data structure template (`LikeDs`), making it reusable by any calling RPG program.
* **Automatic Unit Selection:** Evaluates the optional 2-character country code—requesting **Imperial** (`F`, `mph`) for `US`, `LR`, and `MM`, and defaulting to **Metric** (`C`, `m/s`) for all other countries or omitted codes.
* **Native DB2 JSON Parsing:** Uses `QSYS2.HTTP_GET` paired with `JSON_TABLE` and `Coalesce` / `Default ... On Empty / On Error` handling to safely extract nested JSON values without external third-party libraries.
* **URL Space Encoding:** Automatically encodes spaces in multi-word city names (e.g., `Grand Rapids,MI`) to `%20` using `%ScanRpl` before issuing the HTTP request.
* **Input Validation & Error Handling:** Prevents blank city submissions, clears stale output fields on failed lookups, and highlights errors on the screen via indicator `50`.

## Setup & Usage

1. **Add Your API Key:**
   Obtain a free API key from [OpenWeatherMap](https://openweathermap.org/api) and replace the placeholder in `GETWEATHER.SQLRPGLE`:
   ```rpgle
   Dcl-S apiKey VarChar(50) Inz('YOUR_OPENWEATHERMAP_API_KEY');
   ```
2. **Compile in Order (RDi):**
   * `GETWEATHER.SQLRPGLE`
   * `WEATHDSPF.DSPF`
   * `TESTWEATH.RPGLE`
3. **Run the Program:**
   Ensure your 5250 emulator session is configured for **27×132 (`*DS4`)** screen size, then call `TESTWEATH`. Enter a City/State (e.g., `Paris,MI` or `Grand Rapids,MI`) and optional Country Code (e.g., `US`, `IT`) and press **Enter**.

## Author

**Chris Grimm** — November 19th, 2026