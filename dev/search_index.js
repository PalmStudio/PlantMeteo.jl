var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = PlantMeteo","category":"page"},{"location":"#PlantMeteo","page":"Home","title":"PlantMeteo","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"(Image: Stable) (Image: Dev) (Image: Build Status) (Image: Coverage)","category":"page"},{"location":"#Overview","page":"Home","title":"Overview","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"PlantMeteo is for everything related to meteorological/climatic data related to plant growth. ","category":"page"},{"location":"","page":"Home","title":"Home","text":"The package gives users access to useful and efficient structures, functions for reading and computing data and easy connection to weather APIs:","category":"page"},{"location":"","page":"Home","title":"Home","text":"TimeStepTable to define efficient tables\nAtmosphere to automatically compute atmosphere-related variables from a set of variables\nConstants that provide default values for physical constants (e.g. the universal gas constant or the latent heat of vaporization of water)\nhelper functions such as vapor_pressure, e_sat, air_density, psychrometer_constant or latent_heat_vaporization\neasy download of weather data from renowned APIs such as open-meteo.com with OpenMeteo\nand a framework to easily add more APIs thanks to get_weather","category":"page"},{"location":"#Installation","page":"Home","title":"Installation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"To install the package, enter the Julia package manager mode by pressing ] in the REPL, and execute the following command:","category":"page"},{"location":"","page":"Home","title":"Home","text":"add PlantMeteo","category":"page"},{"location":"","page":"Home","title":"Home","text":"To use the package, execute this command from the Julia REPL:","category":"page"},{"location":"","page":"Home","title":"Home","text":"using PlantMeteo","category":"page"},{"location":"#Projects-that-use-PlantMeteo","page":"Home","title":"Projects that use PlantMeteo","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Take a look at these projects that use PlantSimEngine:","category":"page"},{"location":"","page":"Home","title":"Home","text":"PlantSimEngine.jl\nPlantBiophysics.jl\nXPalm","category":"page"},{"location":"#Make-it-yours","page":"Home","title":"Make it yours","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The package is developed so anyone can easily integrate it into workflows and packages. For example TimeStepTable can be used for any type of data. See the implementation of TimeStepTable{Status} in PlantSimEngine.jl.","category":"page"},{"location":"","page":"Home","title":"Home","text":"If you develop such tools and it is not on the list yet, please make a PR or contact me so we can add it! 😃","category":"page"},{"location":"API/#API","page":"API","title":"API","text":"","category":"section"},{"location":"API/#Index","page":"API","title":"Index","text":"","category":"section"},{"location":"API/","page":"API","title":"API","text":"","category":"page"},{"location":"API/#API-documentation","page":"API","title":"API documentation","text":"","category":"section"},{"location":"API/","page":"API","title":"API","text":"Modules = [PlantMeteo]\n# Private = false","category":"page"},{"location":"API/#PlantMeteo.ATMOSPHERE_COMPUTED","page":"API","title":"PlantMeteo.ATMOSPHERE_COMPUTED","text":"ATMOSPHERE_SELECT\n\nList of variables that are by default removed from the table when using write_weather on a TimeStepTable{Atmosphere}.\n\n\n\n\n\n","category":"constant"},{"location":"API/#PlantMeteo.DEFAULT_OPENMETEO_HOURLY","page":"API","title":"PlantMeteo.DEFAULT_OPENMETEO_HOURLY","text":"DEFAULT_OPENMETEO_HOURLY\n\nDefault variables downloaded for an Open-Meteo forecast. See here for more.\n\n\n\n\n\n","category":"constant"},{"location":"API/#PlantMeteo.OPENMETEO_MODELS","page":"API","title":"PlantMeteo.OPENMETEO_MODELS","text":"OPENMETEO_MODELS\n\nPossible models for the forecast. See here for more details.\n\n\n\n\n\n","category":"constant"},{"location":"API/#PlantMeteo.AbstractAPI","page":"API","title":"PlantMeteo.AbstractAPI","text":"AbstractAPI\n\nAn abstract type for APIs. This is used to define the API to use for the weather forecast. You can get all available APIs using subtype(AbstractAPI).\n\n\n\n\n\n","category":"type"},{"location":"API/#PlantMeteo.AbstractAtmosphere","page":"API","title":"PlantMeteo.AbstractAtmosphere","text":"Abstract atmospheric conditions type. The suptypes of AbstractAtmosphere should describe the atmospheric conditions for one time-step only, see e.g. Atmosphere\n\n\n\n\n\n","category":"type"},{"location":"API/#PlantMeteo.Atmosphere","page":"API","title":"PlantMeteo.Atmosphere","text":"Atmosphere structure to hold all values related to the meteorology / atmosphere.\n\nArguments\n\ndate<:AbstractDateTime = Dates.now(): the date of the record.\nduration<:Period = Dates.Second(1.0): the duration of the time-step in Dates.Period.\nT (°C): air temperature\nWind (m s-1): wind speed\nP = 101.325 (kPa): air pressure. The default value is at 1 atm, i.e. the mean sea-level\n\natmospheric pressure on Earth.\n\nRh = rh_from_vpd(VPD,eₛ) (0-1): relative humidity\nPrecipitations=0.0 (mm): precipitations from atmosphere (i.e. rain, snow, hail, etc.)\nCₐ (ppm): air CO₂ concentration\ne = vapor_pressure(T,Rh) (kPa): vapor pressure\neₛ = e_sat(T) (kPa): saturated vapor pressure\nVPD = eₛ - e (kPa): vapor pressure deficit\nρ = air_density(T, P, constants.Rd, constants.K₀) (kg m-3): air density\nλ = latent_heat_vaporization(T, constants.λ₀) (J kg-1): latent heat of vaporization\nγ = psychrometer_constant(P, λ, constants.Cₚ, constants.ε) (kPa K−1): psychrometer \"constant\"\nε = atmosphere_emissivity(T,e,constants.K₀) (0-1): atmosphere emissivity\nΔ = e_sat_slope(meteo.T) (0-1): slope of the saturation vapor pressure at air temperature\nclearness::A = Inf (0-1): Sky clearness\nRi_SW_f::A = Inf (W m-2): Incoming short wave radiation flux\nRi_PAR_f::A = Inf (W m-2): Incoming PAR flux\nRi_NIR_f::A = Inf (W m-2): Incoming NIR flux\nRi_TIR_f::A = Inf (W m-2): Incoming TIR flux\nRi_custom_f::A = Inf (W m-2): Incoming radiation flux for a custom waveband\n\nNotes\n\nThe structure can be built using only T, Rh, Wind and P. All other variables are optional and either let at their default value or automatically computed using the functions given in Arguments.\n\nExamples\n\nAtmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)\n\n\n\n\n\n","category":"type"},{"location":"API/#PlantMeteo.Constants","page":"API","title":"PlantMeteo.Constants","text":"Physical constants\n\nThe definition and default values are:\n\nK₀ = -273.15: absolute zero (°C)\nR = 8.314: universal gas constant (J mol^-1 K^-1).\nRd = 287.0586: gas constant of dry air (J kg^-1 K^-1).\nDₕ₀ = 21.5e-6: molecular diffusivity for heat at base temperature, applied in the integrated form of the   Fick’s Law of diffusion (m^2 s^-1). See eq. 3.10 from Monteith and Unsworth (2013).\nCₚ = 1013.0: Specific heat of air at constant pressure (J K^-1 kg^-1), also   known as efficiency of impaction of particles. See Allen et al. (1998), or Monteith and   Unsworth (2013). NB: bigleaf R package uses 1004.834 intead.\nε = 0.622: ratio of molecular weights of water vapor and air. See Monteith and   Unsworth (2013).\nλ₀ = 2.501: latent heat of vaporization for water at 0 degree (J kg^-1).\nσ = 5.670373e-08 Stefan-Boltzmann constant   in (W m^-2 K^-4).\nGbₕ_to_Gbₕ₂ₒ = 1.075: conversion coefficient from conductance to heat to conductance to water   vapor.\nGsc_to_Gsw = 1.57: conversion coefficient from stomatal conductance to CO₂ to conductance to water   vapor.\nGbc_to_Gbₕ = 1.32: conversion coefficient from boundary layer conductance to CO₂ to heat.\nMₕ₂ₒ = 18.0e-3 (kg mol-1): Molar mass for water.\n\nReferences\n\nAllen, Richard G., Luis S. Pereira, Dirk Raes, et Martin J Fao Smith. 1998. « Crop evapotranspiration-Guidelines for computing crop water requirements-FAO Irrigation and drainage paper 56 » 300 (9): D05109.\n\nMonteith, John, et Mike Unsworth. 2013. Principles of environmental physics: plants, animals, and the atmosphere. Academic Press.\n\n\n\n\n\n","category":"type"},{"location":"API/#PlantMeteo.OpenMeteo","page":"API","title":"PlantMeteo.OpenMeteo","text":"OpenMeteo()\nOpenMeteo(\n    vars=PlantMeteo.DEFAULT_OPENMETEO_HOURLY,\n    forecast_server=\"https://api.open-meteo.com/v1/forecast\",\n    historical_server=\"https://archive-api.open-meteo.com/v1/era5\",\n    units=OpenMeteoUnits(),\n    timezone=\"UTC\",\n    models=[\"auto\"]\n)\n\nA type that defines the open-meteo.com API.  No need of an API key as it is free. Please keep in mind that the API is distributed under the AGPL license, that it is not free for commercial use, and that you should use it responsibly.\n\nNotes\n\nThe API wrapper provided by PlantMeteo is only working for the hourly data as daily data is missing  some variables. The API wrapper is also not working for the \"soil\" variables as they are not consistant between forecast and historical data.\n\nSee also\n\nto_daily\n\nArguments\n\nvars: the variables needed, see here.\nforecast_server: the server to use for the forecast, see \n\nhere. Default to https://api.open-meteo.com/v1/forecast.\n\nhistorical_server: the server to use for the historical data, see \n\nhere. Default to https://archive-api.open-meteo.com/v1/era5.\n\nunits::OpenMeteoUnits: the units used for the variables, see OpenMeteoUnits.\ntimezone: the timezone used for the data, see the list here. \n\nDefault to \"UTC\". This parameter is not checked, so be careful when using it.\n\nmodels: the models to use for the forecast. Default to \"[\"best_match\"]\". See OPENMETEO_MODELS for more details.\n\nDetails\n\nThe default variables are: \"temperature2m\", \"relativehumidity2m\", \"precipitation\", \"surfacepressure\", \"windspeed10m\", \"shortwaveradiation\", \"directradiation\", \"diffuse_radiation\".\n\nNote that we don't download: \"soiltemperature0cm\", \"soiltemperature6cm\", \"soiltemperature18cm\", \"soiltemperature54cm\", \"soilmoisture01cm\", \"soilmoisture13cm\", \"soilmoisture39cm\", \"soilmoisture927cm\" and \"soilmoisture27_81cm\"  by default as they are not consistant between forecast and hystorical data.\n\nSources\n\nOpen-Meteo.com, under Attribution \n\n4.0 International (CC BY 4.0).\n\nCopernicus Climate Change Service information 2022 (Hersbach et al., 2018).\n\nHersbach, H., Bell, B., Berrisford, P., Biavati, G., Horányi, A., Muñoz Sabater, J., Nicolas, J.,  Peubey, C., Radu, R., Rozum, I., Schepers, D., Simmons, A., Soci, C., Dee, D., Thépaut, J-N. (2018):  ERA5 hourly data on single levels from 1959 to present.  Copernicus Climate Change Service (C3S) Climate Data Store (CDS). (Updated daily), 10.24381/cds.adbb2d47\n\n\n\n\n\n","category":"type"},{"location":"API/#PlantMeteo.OpenMeteoUnits","page":"API","title":"PlantMeteo.OpenMeteoUnits","text":"OpenMeteoUnits(temperature_unit, windspeed_unit, precipitation_unit)\nOpenMeteoUnits(;temperature_unit=\"celsius\", windspeed_unit=\"ms\", precipitation_unit=\"mm\")\n\nA type that defines the units used for the variabels when calling the open-meteo.com API.\n\nArguments\n\ntemperature_unit: the temperature unit, can be \"celsius\" or \"fahrenheit\". Default to \"celsius\".\nwindspeed_unit: the windspeed unit, can be \"ms\", \"kmh\", \"mph\", or \"kn\". Default to \"ms\".\nprecipitation_unit: the precipitation unit, can be \"mm\" or \"inch\". Default to \"mm\".\n\nExamples\n\njulia> units = OpenMeteoUnits(\"celsius\", \"ms\", \"mm\")\nOpenMeteoUnits(\"celsius\", \"ms\", \"mm\")\n\n\n\n\n\n","category":"type"},{"location":"API/#PlantMeteo.TimeStepTable","page":"API","title":"PlantMeteo.TimeStepTable","text":"TimeStepTable(vars)\n\nTimeStepTable stores variables values for each time step, e.g. weather variables. It implements the Tables.jl interface, so it can be used with any package that uses  Tables.jl (like DataFrames.jl).\n\nYou can extend TimeStepTable to store your own variables by defining a new type for the  storage of the variables. You can look at the Atmosphere type  for an example implementation, or the Status type from  PlantSimEngine.jl.\n\nExamples\n\ndata = TimeStepTable(\n    [\n        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),\n        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),\n        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)\n    ]\n)\n\n# We can convert it into a DataFrame:\nusing DataFrames\ndf = DataFrame(data)\n\n# We can also create a TimeStepTable from a DataFrame:\nTimeStepTable(df)\n\n# Note that by default it will use NamedTuple to store the variables\n# for high performance. If you want to use a different type, you can\n# specify it as a type parameter (if you want *e.g.* mutability or pre-computations):\nTimeStepTable{Atmosphere}(df)\n# Or if you use PlantSimEngine: TimeStepTable{Status}(df)\n\n\n\n\n\n","category":"type"},{"location":"API/#PlantMeteo.Weather-Union{Tuple{Any}, Tuple{S}, Tuple{Any, S}} where S<:NamedTuple","page":"API","title":"PlantMeteo.Weather","text":"Weather(data[, metadata])\n\nDefines the weather, i.e. the local conditions of the Atmosphere for one or more time-steps. Each time-step is described using the Atmosphere structure, and the resulting structure is a TimeStepTable.\n\nThe simplest way to instantiate a Weather is to use a DataFrame as input.\n\nThe DataFrame should be formated such as each row is an observation for a given time-step and each column is a variable. The column names should match exactly the variables names of the Atmosphere structure:\n\nSee also\n\nthe Atmosphere structure\nthe read_weather function to read Archimed-formatted meteorology data.\n\nExamples\n\nExample of weather data defined by hand (cumbersome):\n\nw = Weather(\n    [\n        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),\n        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),\n        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)\n    ],\n    (\n        site = \"Test site\",\n        important_metadata = \"this is important and will be attached to our weather data\"\n    )\n)\n\nWeather is a TimeStepTable{Atmosphere}, so we can convert it into a DataFrame:\n\nusing DataFrames\ndf = DataFrame(w)\n\nAnd then back into Weather to make a TimeStepTable{Atmosphere}:\n\nWeather(df, (site = \"My site\",))\n\nOf course it works with any DataFrame that has at least the required variables listed in Atmosphere.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.add_transformations!-NTuple{4, Any}","page":"API","title":"PlantMeteo.add_transformations!","text":"add_transformations!(df, trans, vars, fun; error_missing=false)\n\nAdd the fun transformations to the trans vector for the  variables vars found in the df DataFrame.\n\nArguments\n\ndf: the DataFrame\ntrans: the vector of transformations (will be modified in-place)\nvars: the variables to transform (can be a symbol, a vector of symbols or a pairs :var => :new_var)\nfun: the function to apply to the variables\nerror_missing=true: if true, the function returns an error if the variable is not found. If false, \n\nthe variable is not added to trans.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.air_density-NTuple{4, Any}","page":"API","title":"PlantMeteo.air_density","text":"air_density(Tₐ, P)\nair_density(Tₐ, P, Rd, K₀)\n\nρ, the air density (kg m-3).\n\nArguments\n\nTₐ (Celsius degree): air temperature\nP (kPa): air pressure\nRd (J kg-1 K-1): gas constant of dry air (see Foken p. 245, or R bigleaf package).\nK₀ (Celsius degree): temperature in Celsius degree at 0 Kelvin\n\nNote\n\nRd and K₀ are Taken from Constants if not provided.\n\nReferences\n\nFoken, T, 2008: Micrometeorology. Springer, Berlin, Germany.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.atmosphere_emissivity-Tuple{Any, Any, Any}","page":"API","title":"PlantMeteo.atmosphere_emissivity","text":"atmosphere_emissivity(Tₐ,eₐ)\n\nEmissivity of the atmoshpere at a given temperature and vapor pressure.\n\nArguments\n\nTₐ (°C): air temperature\neₐ (kPa): air vapor pressure\nK₀ (°C): absolute zero\n\nExamples\n\nTₐ = 20.0\nVPD = 1.5\natmosphere_emissivity(Tₐ, vapor_pressure(Tₐ,VPD))\n\nReferences\n\nLeuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. Leaf nitrogen, photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant, Cell & Environment 18 (10): 1183‑1200.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.check_day_complete-Tuple{Any}","page":"API","title":"PlantMeteo.check_day_complete","text":"check_day_complete(df)\n\nCheck that the weather table df has full days (24h) of data by  summing their durations.\n\ndf must be a Tables.jl compatible table with a date and duration column. The date column must be a Dates.DateTime column, and the duration column  must be a Dates.Period or Dates.CompoundPeriod column.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.compute_date","page":"API","title":"PlantMeteo.compute_date","text":"compute_date(data, date_format, hour_format)\n\nCompute the date column depending on several cases:\n\nIf it is already in data and is a DateTime, does nothing.\nIf it is a String, tries and parse it using a user-input DateFormat\nIf it is a Date, return it as is, or try to make it a DateTime if there's a column named\n\nhour_start\n\nArguments\n\ndata: any Tables.jl compatible table, such as a DataFrame\ndate_format: a DateFormat to parse the date column if it is a String\nhour_format: a DateFormat to parse the hour_start column if it is a String\n\n\n\n\n\n","category":"function"},{"location":"API/#PlantMeteo.compute_duration","page":"API","title":"PlantMeteo.compute_duration","text":"compute_duration(data, hour_format, duration)\n\nCompute the duration column depending on several cases:\n\nIf it is already in the data, use the duration function to parse it into a Date.Period.\nIf it is not, but there's a column named hour_end and another one either called hour_start\n\nor date, compute the duration from the period between hour_start (or date) and hour_end.\n\nArguments\n\ndata: any Tables.jl compatible table, such as a DataFrame\nhour_format: a DateFormat to parse the hour_start and hour_end columns if they are Strings.\nduration: a function to parse the duration column. Usually Dates.Day or Dates.Minute.\n\n\n\n\n\n","category":"function"},{"location":"API/#PlantMeteo.default_transformation-Tuple{Any}","page":"API","title":"PlantMeteo.default_transformation","text":"default_transformation(df)\n\nReturn the default transformations to apply to the df DataFrame  for the to_daily function. If the variable is not available, the transformation is not applied.\n\nThe default transformations are:\n\n:date => (x -> unique(Dates.Date.(x))) => :date: the date is transformed into a Date object\n:duration => sum => :duration: the duration is summed\n:T => minimum => :Tmin: we use the minimum temperature for Tmin\n:T => maximum => :Tmax: and the maximum temperature for Tmax\n:T => mean => :T: and the average daily temperature (!= than average of Tmin and Tmax)\n:Precipitations => sum => :Precipitations: the precipitations are summed\n:Rh => mean => :Rh: the relative humidity is averaged\n:Wind, :P, :Rh, :Cₐ, :e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness are \n\nall averaged\n\n:Ri_SW_f => mean => :Ri_SW_f: the irradiance is averaged (W m-2)\n[:Ri_SW_f, :duration] => ((x, y) -> sum(x .* Dates.toms.(y)) * 1.0e-9) => :Ri_SW_q: the irradiance is also summed (MJ m-2 d-1)\nAll other irradiance variables are also averaged or integrated (see the code for details)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.e_sat-Tuple{Any}","page":"API","title":"PlantMeteo.e_sat","text":"e_sat(T)\n\nSaturated water vapour pressure (es, in kPa) at given temperature T (°C). See Jones (1992) p. 110 for the equation.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.e_sat_slope-Tuple{Any}","page":"API","title":"PlantMeteo.e_sat_slope","text":"e_sat_slope(T)\n\nSlope of the vapor pressure saturation curve at a given temperature T (°C).\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.fetch_openmeteo-Union{Tuple{T}, Tuple{Any, Any, Any, Any, Any, T}} where T<:OpenMeteo","page":"API","title":"PlantMeteo.fetch_openmeteo","text":"fetch_openmeteo(url, lat, lon, start_date, end_date, params::OpenMeteo)\n\nFetches the weather forecast from OpenMeteo.com and returns a tuple of: \n\na vector of Atmosphere\na NamedTuple of metadata (e.g. elevation, timezone, units...)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.format_openmeteo!-Tuple{Any}","page":"API","title":"PlantMeteo.format_openmeteo!","text":"format_openmeteo(data)\n\nFormat the JSON file returned by the Open-Meteo API into a vector  of Atmosphere. The function also updates some units in data.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.get_forecast-Tuple{OpenMeteo, Any, Any, Any}","page":"API","title":"PlantMeteo.get_forecast","text":"get_forecast(params::OpenMeteo, lat, lon, period; verbose=true)\n\nA function that returns the weather forecast from OpenMeteo.com\n\nArguments\n\nlat: Latitude of the location\nlon: Longitude of the location\nperiod::Union{StepRange{Date, Day}, Vector{Dates.Date}}: Period of the forecast\nverbose: If true, print more information in case of errors or warnings.\n\nExamples\n\nusing PlantMeteo, Dates\nlat = 48.8566\nlon = 2.3522\nperiod = [Dates.today(), Dates.today()+Dates.Day(3)]\nparams = OpenMeteo()\nget_forecast(params, lat, lon, period)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.get_index_raw-Tuple{TimeStepTable, Integer}","page":"API","title":"PlantMeteo.get_index_raw","text":"get_index_raw(ts::TimeStepTable, i::Integer)\n\nGet row from TimeStepTable in its raw format, e.g. as a NamedTuple or Atmosphere of values.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.get_weather-Union{Tuple{P}, Tuple{Any, Any, P}} where P<:Union{StepRange{Date, Day}, Vector{Date}}","page":"API","title":"PlantMeteo.get_weather","text":"get_weather(lat, lon, period::Union{StepRange{Date, Day}, Vector{Dates.Date}}; api::DataType=OpenMeteo, sink=TimeStepTable)\n\nReturns the weather forecast for a given location and time using a weather API.\n\nArguments\n\nlat::Float64: Latitude of the location in degrees\nlon::Float64: Longitude of the location in degrees\nperiod::Union{StepRange{Date, Day}, Vector{Dates.Date}}: Period of the forecast\napi::DataType=OpenMeteo: API to use for the forecast.\nsink::DataType=TimeStepTable: Type of the output. Default is TimeStepTable, but it\n\ncan be any type that implements the Tables.jl interface, such as DataFrames.\n\nDetails\n\nWe can get all available APIs using subtype(AbstractAPI). Please keep in mind that the default OpenMeteo API is not free for commercial use, and that you should use it responsibly.\n\nExamples\n\nusing PlantMeteo, Dates\n# Forecast for today and tomorrow:\nperiod = [today(), today()+Dates.Day(1)]\nw = get_weather(48.8566, 2.3522, period)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.latent_heat_vaporization-Tuple{Any, Any}","page":"API","title":"PlantMeteo.latent_heat_vaporization","text":"latent_heat_vaporization(Tₐ,λ₀)\nlatent_heat_vaporization(Tₐ)\n\nλ, the latent heat of vaporization for water (J kg-1).\n\nArguments\n\nTₐ (°C): air temperature\nλ₀: latent heat of vaporization for water at 0 degree Celsius. Taken from Constants().λ₀\n\nif not provided (see Constants).\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.new_names-Tuple{Any}","page":"API","title":"PlantMeteo.new_names","text":"new_names(args)\n\nGet the new names of the columns after the transformation provided  by the user.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.parse_hour","page":"API","title":"PlantMeteo.parse_hour","text":"parse_hour(h, hour_format=Dates.DateFormat(\"HH:MM:SS\"))\n\nParse an hour that can be of several formats:\n\nTime: return it as is\nString: try to parse it using the user-input DateFormat\nDateTime: transform it into a Time\n\nArguments\n\nh: hour to parse\nhour_format::DateFormat: user-input format to parse the hours\n\nExamples\n\njulia> using PlantMeteo, Dates;\n\nAs a string:\n\njulia> PlantMeteo.parse_hour(\"12:00:00\")\n12:00:00\n\nAs a Time:\n\njulia> PlantMeteo.parse_hour(Dates.Time(12, 0, 0))\n12:00:00\n\nAs a DateTime:\n\njulia> PlantMeteo.parse_hour(Dates.DateTime(2020, 1, 1, 12, 0, 0))\n12:00:00\n\n\n\n\n\n","category":"function"},{"location":"API/#PlantMeteo.psychrometer_constant-NTuple{4, Any}","page":"API","title":"PlantMeteo.psychrometer_constant","text":"psychrometer_constant(P, λ, Cₚ, ε)\npsychrometer_constant(P, λ)\n\nγ, the psychrometer constant, also called psychrometric constant (kPa K−1). See Monteith and Unsworth (2013), p. 222.\n\nArguments\n\nP (kPa): air pressure\nλ (J kg^-1): latent heat of vaporization for water (see latent_heat_vaporization)\nCₚ (J kg-1 K-1): specific heat of air at constant pressure (J K^-1 kg^-1)\nε (Celsius degree): temperature in Celsius degree at 0 Kelvin\n\nNote\n\nCₚ, ε and λ₀ are taken from Constants if not provided.\n\nTₐ = 20.0\n\nλ = latent_heat_vaporization(Tₐ, λ₀)\npsychrometer_constant(100.0, λ)\n\nReferences\n\nMonteith, John L., et Mike H. Unsworth. 2013. « Chapter 13 - Steady-State Heat Balance: (i) Water Surfaces, Soil, and Vegetation ». In Principles of Environmental Physics (Fourth Edition), edited by John L. Monteith et Mike H. Unsworth, 217‑47. Boston: Academic Press.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.raw_row-Tuple{PlantMeteo.TimeStepRow}","page":"API","title":"PlantMeteo.raw_row","text":"raw_row(ts::TimeStepRow)\n\nGet TimeStepRow in its raw format, e.g. as a NamedTuple or Atmosphere of values.\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.read_weather-Tuple{Any, Vararg{Any}}","page":"API","title":"PlantMeteo.read_weather","text":"read_weather(\n    file[,args...];\n    date_format = DateFormat(\"yyyy-mm-ddTHH:MM:SS.s\"),\n    hour_format = DateFormat(\"HH:MM:SS\"),\n    duration=nothing\n)\n\nRead a meteo file. The meteo file is a CSV, and optionnaly with metadata in a header formatted as a commented YAML. The column names and units should match exactly the fields of Atmosphere, or  the user should provide their transformation as arguments (args) with the DataFrames.jl form, i.e.: \n\n:var_name => (x -> x .+ 1) => :new_name: the variable :var_name is transformed by the function    x -> x .+ 1 and renamed to :new_name\n:var_name => :new_name: the variable :var_name is renamed to :new_name\n:var_name: the variable :var_name is kept as is\n\nNote\n\nThe variables found in the file will be used as is if not transformed, and not recomputed from the other variables. Please check that all variables have the same units as in the Atmosphere structure.\n\nArguments\n\nfile::String: path to a meteo file\nargs...: A list of arguments to transform the table. See above to see the possible forms.\ndate_format = DateFormat(\"yyyy-mm-ddTHH:MM:SS.s\"): the format for the DateTime columns\nhour_format = DateFormat(\"HH:MM:SS\"): the format for the Time columns (e.g. hour_start)\nduration: a function to parse the duration column if present in the file. Usually Dates.Day or Dates.Minute.\n\nIf the column is absent, the duration will be computed using the hour_format and the hour_start and hour_end columns along with the date column.\n\nExamples\n\nusing PlantMeteo, Dates\n\nfile = joinpath(dirname(dirname(pathof(PlantMeteo))),\"test\",\"data\",\"meteo.csv\")\n\nmeteo = read_weather(\n    file,\n    :temperature => :T,\n    :relativeHumidity => (x -> x ./100) => :Rh,\n    :wind => :Wind,\n    :atmosphereCO2_ppm => :Cₐ,\n    date_format = DateFormat(\"yyyy/mm/dd\")\n)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.rh_from_e-Tuple{Any, Any}","page":"API","title":"PlantMeteo.rh_from_e","text":"rh_from_e(VPD,eₛ)\n\nConversion between e (kPa) and rh (0-1).\n\nExamples\n\nrh_from_e(1.5,25.0)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.rh_from_vpd-Tuple{Any, Any}","page":"API","title":"PlantMeteo.rh_from_vpd","text":"rh_from_vpd(VPD,eₛ)\n\nConversion between VPD and rh.\n\nExamples\n\neₛ = e_sat(Tₐ)\nrh_from_vpd(1.5,eₛ)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.timesteps_durations-Tuple{Vector{DateTime}}","page":"API","title":"PlantMeteo.timesteps_durations","text":"timesteps_durations(datetime::Dates.DateTime; verbose=true)\n\nDuration in sensible units (e.g. 1 hour, or 1 day), computed as the  duration between a step and the previous step. The first one is unknown, so we force it as the same as all (if unique), or the second one (if not) with a warning.\n\nThe function returns a Dates.CompoundPeriod because it helps finding a sensible default from a milliseconds period (e.g. 1 Hour or 1 Day).\n\nArguments\n\ndatetime::Vector{Dates.DateTime}: Vector of dates\nverbose::Bool=true: If true, print a warning if the duration is not \n\nconstant between the time steps.\n\nExamples\n\njulia> timesteps_durations([Dates.DateTime(2019, 1, 1, 0), Dates.DateTime(2019, 1, 1, 1)])\n2-element Vector{Dates.CompoundPeriod}:\n 1 hour\n 1 hour\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.to_daily-Tuple{DataFrames.DataFrame, Vararg{Any}}","page":"API","title":"PlantMeteo.to_daily","text":"to_daily(df, args...)\nto_daily(t::T, args...) where {T<:TimeStepTable{<:Atmosphere}}\n\nTransform a DataFrame object or TimeStepTable{<:Atmosphere} with sub-daily time steps (e.g. 1h) to a daily time-step table.\n\nArguments\n\nt: a TimeStepTable{<:Atmosphere} with sub-daily time steps (e.g. 1h)\nargs: a list of transformations to apply to the data, formates as for DataFrames.jl\n\nNotes\n\nDefault transformations are applied to the data, and can be overriden by the user. The default transformations are:\n\n:date => (x -> unique(Dates.Date.(x))) => :date: the date is transformed into a Date object\n:duration => sum => :duration: the duration is summed\n:T => minimum => :Tmin: we use the minimum temperature for Tmin\n:T => maximum => :Tmax: and the maximum temperature for Tmax\n:Precipitations => sum => :Precipitations: the precipitations are summed\n:Rh => mean => :Rh: the relative humidity is averaged\n:Wind, :P, :Rh, :Cₐ, :e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness are \n\nall averaged\n\n:Ri_SW_f => mean => :Ri_SW_f: the irradiance is averaged (W m-2)\n[:Ri_SW_f, :duration] => ((x, y) -> sum(x .* Dates.toms.(y)) * 1.0e-9) => :Ri_SW_q: the irradiance is also summed (MJ m-2 d-1)\nAll other irradiance variables are also averaged or integrated (see the code for details)\n\nNote that the default transformations can be overriden by the user, and that the default transformations are only applied if the variable is available.\n\nExamples\n\nusing PlantMeteo, Dates\n# Forecast for today and tomorrow:\nperiod = [today(), today()+Dates.Day(1)]\nw = get_weather(48.8566, 2.3522, period)\n# Convert to daily:\nw_daily = to_daily(w, :T => mean => :Tmean)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.vapor_pressure-Tuple{Any, Any}","page":"API","title":"PlantMeteo.vapor_pressure","text":"vapor_pressure(Tₐ, rh)\n\nVapor pressure (kPa) at given temperature (°C) and relative hunidity (0-1).\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.vpd-Tuple{Any, Any}","page":"API","title":"PlantMeteo.vpd","text":"vpd(VPD,eₛ)\n\nCompute vapor pressure deficit (kPa) from the air relative humidity (0-1) and temperature (°C).\n\nThe computation simply uses vpd = eₛ - e.\n\nExamples\n\nvpd(0.4,25.0)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.write_weather-Union{Tuple{T}, Tuple{String, T}} where T<:(TimeStepTable{<:Atmosphere})","page":"API","title":"PlantMeteo.write_weather","text":"write_weather(\n    file, w; \n    select=setdiff(propertynames(w), ATMOSPHERE_COMPUTED),\n    duration=Dates.Minute\n)\n\nWrite the weather data to a file. \n\nArguments\n\nfile: a String representing the path to the file to write\nw: a TimeStepTable{Atmosphere}\nselect: a vector of variables to write (as symbols). By default, all variables are written except the ones that \n\ncan be recomputed (see ATMOSPHERE_COMPUTED). If nothing is given, all variables are written.\n\nduration: the unit for formating the duration of the time steps. By default, it is Dates.Minute.\n\nExamples\n\nusing PlantMeteo, Dates\n\nfile = joinpath(dirname(dirname(pathof(PlantMeteo))),\"test\",\"data\",\"meteo.csv\")\nw = read_weather(\n    file,\n    :temperature => :T,\n    :relativeHumidity => (x -> x ./100) => :Rh,\n    :wind => :Wind,\n    :atmosphereCO2_ppm => :Cₐ,\n    date_format = DateFormat(\"yyyy/mm/dd\")\n)\n\nwrite_weather(\"meteo.csv\", w)\n\n\n\n\n\n","category":"method"},{"location":"API/#PlantMeteo.write_weather_-Tuple{String, Any}","page":"API","title":"PlantMeteo.write_weather_","text":"write_weather_(file, w)\n\nWrite the weather data to a file with a special-commented yaml header for the metadata.\n\n\n\n\n\n","category":"method"}]
}
