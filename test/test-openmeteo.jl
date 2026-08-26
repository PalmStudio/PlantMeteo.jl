lat = 48.8566
lon = 2.3522

vars = (
    :date, :duration, :T, :Wind, :P, :Rh, :Precipitations, :Cₐ, :e,
    :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :Ri_SW_f, :Ri_PAR_f,
    :Ri_NIR_f, :Ri_SW_f_direct, :Ri_SW_f_diffuse
)

@testset "OpenMeteo forecast data" begin
    period = [today(), today() + Dates.Day(1)]
    w = get_forecast(OpenMeteo(), lat, lon, period; verbose=false)
    @test length(w) == 48 # 2 x 24 hours
    @test typeof(w) == TimeStepTable{Atmosphere}
    @test typeof(w.T) == Vector{Float64}
    @test keys(w) == vars
end

function openmeteo_payload()
    Dict(
        "latitude" => lat,
        "longitude" => lon,
        "elevation" => 35.0,
        "timezone" => "UTC",
        "timezone_abbreviation" => "UTC",
        "hourly_units" => Dict(
            "time" => "iso8601",
            "temperature_2m" => "°C",
            "relativehumidity_2m" => "%",
            "precipitation" => "mm",
            "surface_pressure" => "hPa",
            "windspeed_10m" => "m/s",
            "shortwave_radiation" => "W/m²",
            "direct_radiation" => "W/m²",
            "diffuse_radiation" => "W/m²",
        ),
        "hourly" => Dict(
            "time" => ["2025-07-01T00:00", "2025-07-01T01:00"],
            "temperature_2m" => [25.0, 24.0],
            "relativehumidity_2m" => [70.0, 72.0],
            "precipitation" => [0.0, 0.5],
            "surface_pressure" => [1013.0, 1012.0],
            "windspeed_10m" => [2.0, 1.5],
            "shortwave_radiation" => [0.0, 0.0],
            "direct_radiation" => [0.0, 0.0],
            "diffuse_radiation" => [0.0, 0.0],
        ),
    )
end

function capture_error(f)
    try
        f()
        return nothing
    catch err
        return err
    end
end

@static if hasfield(PlantMeteo.HTTP.TimeoutError, :readtimeout)
    openmeteo_timeout_error() = PlantMeteo.HTTP.TimeoutError(Int64(1))
else
    openmeteo_timeout_error() = PlantMeteo.HTTP.TimeoutError("request", Int64(1))
end

@testset "OpenMeteo retries transient failures" begin
    attempts = Ref(0)
    sleep_calls = Float64[]
    request_get(url; status_exception=false) = begin
        attempts[] += 1
        attempts[] < 3 && throw(openmeteo_timeout_error())
        PlantMeteo.HTTP.Response(200, PlantMeteo.JSON.json(openmeteo_payload()))
    end

    weather, metadata = PlantMeteo.fetch_openmeteo(
        "https://example.test",
        lat,
        lon,
        "2025-07-01",
        "2025-07-01",
        OpenMeteo();
        segment="forecast",
        request_get=request_get,
        retries=2,
        retry_delay=0.25,
        sleep_fn=x -> push!(sleep_calls, x)
    )

    @test attempts[] == 3
    @test sleep_calls == [0.25, 0.5]
    @test length(weather) == 2
    @test metadata.timezone == "UTC"
    @test weather[1].Rh ≈ 0.7
    @test weather[1].P ≈ 101.3
    @test metadata.units["temperature_2m"] == "°C"
    @test metadata.units["windspeed_10m"] == "m/s"
    @test metadata.units["relativehumidity_2m"] == "0-1"
    @test metadata.units["surface_pressure"] == "kPa"
    @test metadata.source_units["relativehumidity_2m"] == "%"
    @test metadata.source_units["surface_pressure"] == "hPa"
    @test length(metadata.import_normalization) == 1
    @test metadata.import_normalization[1]["input_units"] ==
          Dict{String,Any}(
              "T" => "celsius",
              "Wind" => "ms",
              "Precipitations" => "mm",
              "Rh" => "percent",
              "P" => "hPa",
          )
    @test metadata.import_normalization[1]["conversions"] == [
        Dict{String,Any}(
            "variable" => "Rh",
            "input_unit" => "percent",
            "output_unit" => "fraction",
            "scale" => 0.01,
        ),
        Dict{String,Any}(
            "variable" => "P",
            "input_unit" => "hPa",
            "output_unit" => "kPa",
            "scale" => 0.1,
        ),
    ]
end

@testset "OpenMeteo does not invent missing or invalid core forcing" begin
    missing_pressure = openmeteo_payload()
    missing_pressure["hourly"]["surface_pressure"] = Any[nothing, 1012.0]
    @test_throws "Surface pressure data is `nothing`" PlantMeteo.format_openmeteo(missing_pressure)

    calm_wind = openmeteo_payload()
    calm_wind["hourly"]["windspeed_10m"][1] = 0.0
    calm = PlantMeteo.format_openmeteo(calm_wind).atmospheres
    @test calm[1].Wind == 0.0

    negative_wind = openmeteo_payload()
    negative_wind["hourly"]["windspeed_10m"][1] = -1.0
    @test_throws "Wind speed (-1.0) must be non-negative" PlantMeteo.format_openmeteo(negative_wind)

    invalid_pressure = openmeteo_payload()
    invalid_pressure["hourly"]["surface_pressure"][1] = 500.0
    @test_throws "Air pressure (50.0) is not in the 85-110 kPa earth range" PlantMeteo.format_openmeteo(invalid_pressure)

    wrong_units = openmeteo_payload()
    wrong_units["hourly_units"]["surface_pressure"] = "Pa"
    @test_throws "Open-Meteo unit for `surface_pressure` must be `hPa`" PlantMeteo.format_openmeteo(wrong_units)

    wrong_radiation_units = openmeteo_payload()
    wrong_radiation_units["hourly_units"]["shortwave_radiation"] = "kW/m²"
    @test_throws "Open-Meteo unit for `shortwave_radiation` must be `W/m²`" PlantMeteo.format_openmeteo(wrong_radiation_units)

    wrong_time_units = openmeteo_payload()
    wrong_time_units["hourly_units"]["time"] = "unixtime"
    @test_throws "Open-Meteo unit for `time` must be `iso8601`" PlantMeteo.format_openmeteo(wrong_time_units)
end

@testset "OpenMeteo converts every supported declared unit" begin
    cases = (
        (
            name=:fahrenheit,
            units=OpenMeteoUnits(temperature_unit="fahrenheit"),
            payload_key="temperature_2m",
            payload_unit="°F",
            source_value=68.0,
            field=:T,
            expected=20.0,
            input_unit="fahrenheit",
            output_unit="celsius",
            scale=5.0 / 9.0,
            offset=-32.0 * 5.0 / 9.0,
        ),
        (
            name=:kmh,
            units=OpenMeteoUnits(windspeed_unit="kmh"),
            payload_key="windspeed_10m",
            payload_unit="km/h",
            source_value=36.0,
            field=:Wind,
            expected=10.0,
            input_unit="kmh",
            output_unit="ms",
            scale=1.0 / 3.6,
            offset=nothing,
        ),
        (
            name=:mph,
            units=OpenMeteoUnits(windspeed_unit="mph"),
            payload_key="windspeed_10m",
            payload_unit="mp/h",
            source_value=10.0,
            field=:Wind,
            expected=4.4704,
            input_unit="mph",
            output_unit="ms",
            scale=0.44704,
            offset=nothing,
        ),
        (
            name=:kn,
            units=OpenMeteoUnits(windspeed_unit="kn"),
            payload_key="windspeed_10m",
            payload_unit="kn",
            source_value=10.0,
            field=:Wind,
            expected=10.0 * 1852.0 / 3600.0,
            input_unit="kn",
            output_unit="ms",
            scale=1852.0 / 3600.0,
            offset=nothing,
        ),
        (
            name=:inch,
            units=OpenMeteoUnits(precipitation_unit="inch"),
            payload_key="precipitation",
            payload_unit="inch",
            source_value=1.0,
            field=:Precipitations,
            expected=25.4,
            input_unit="inch",
            output_unit="mm",
            scale=25.4,
            offset=nothing,
        ),
    )

    for case in cases
        @testset "$(case.name)" begin
            payload = openmeteo_payload()
            payload["hourly_units"][case.payload_key] = case.payload_unit
            payload["hourly"][case.payload_key][1] = case.source_value
            source_payload = deepcopy(payload)

            formatted = PlantMeteo.format_openmeteo(payload, case.units)
            @test payload == source_payload
            @test getproperty(formatted.atmospheres[1], case.field) ≈ case.expected

            records = filter(
                record -> record["variable"] == string(case.field),
                formatted.import_normalization[1]["conversions"],
            )
            @test length(records) == 1
            @test records[1]["input_unit"] == case.input_unit
            @test records[1]["output_unit"] == case.output_unit
            @test records[1]["scale"] ≈ case.scale
            if case.offset === nothing
                @test !haskey(records[1], "offset")
            else
                @test records[1]["offset"] ≈ case.offset
            end
        end
    end
end

@testset "OpenMeteo non-canonical provenance survives write/read" begin
    units = OpenMeteoUnits(
        temperature_unit="fahrenheit",
        windspeed_unit="mph",
        precipitation_unit="inch",
    )
    payload = openmeteo_payload()
    payload["hourly_units"]["temperature_2m"] = "°F"
    payload["hourly_units"]["windspeed_10m"] = "mp/h"
    payload["hourly_units"]["precipitation"] = "inch"
    payload["hourly"]["temperature_2m"] = [68.0, 69.8]
    payload["hourly"]["windspeed_10m"] = [10.0, 5.0]
    payload["hourly"]["precipitation"] = [1.0, 0.5]
    request_get(url; status_exception=false) =
        PlantMeteo.HTTP.Response(200, PlantMeteo.JSON.json(payload))

    rows, source_metadata = PlantMeteo.fetch_openmeteo(
        "https://example.test",
        lat,
        lon,
        "2025-07-01",
        "2025-07-01",
        OpenMeteo(units=units);
        request_get=request_get,
    )
    weather = Weather(rows, source_metadata)
    @test weather[1].T ≈ 20.0
    @test weather[1].Wind ≈ 4.4704
    @test weather[1].Precipitations ≈ 25.4
    @test source_metadata.units["temperature_2m"] == "°C"
    @test source_metadata.units["windspeed_10m"] == "m/s"
    @test source_metadata.units["precipitation"] == "mm"
    @test source_metadata.source_units["temperature_2m"] == "°F"
    @test source_metadata.source_units["windspeed_10m"] == "mp/h"
    @test source_metadata.source_units["precipitation"] == "inch"

    mktemp() do path, io
        write_weather(path, weather; duration=Dates.Second)
        reread = read_weather(path; duration=Dates.Second)
        history = metadata(reread, :import_normalization)
        @test history isa Vector{Dict{String,Any}}
        @test history[1] == source_metadata.import_normalization[1]
        @test length(history) == 2
        @test metadata(reread, :units) == source_metadata.units
        @test metadata(reread, :source_units) == source_metadata.source_units
    end
end

@testset "OpenMeteo formats connection failures" begin
    err = PlantMeteo.HTTP.ConnectError("example.test:443", ErrorException("connection refused"))
    @test PlantMeteo.is_transient_openmeteo_error(err)
    @test occursin("connection refused", PlantMeteo.openmeteo_error_reason(err))
end

@static if isdefined(PlantMeteo.HTTP, :TLSHandshakeError)
    @testset "OpenMeteo classifies TLS handshake failures as transient" begin
        err = PlantMeteo.HTTP.TLSHandshakeError(ErrorException("i/o timeout"))
        @test PlantMeteo.is_transient_openmeteo_error(err)
    end
end

@testset "OpenMeteo retries retryable HTTP status codes" begin
    attempts = Ref(0)
    sleep_calls = Float64[]
    request_get(url; status_exception=false) = begin
        attempts[] += 1
        attempts[] < 3 && return PlantMeteo.HTTP.Response(503, PlantMeteo.JSON.json(Dict("error" => true)))
        PlantMeteo.HTTP.Response(200, PlantMeteo.JSON.json(openmeteo_payload()))
    end

    weather, _ = PlantMeteo.fetch_openmeteo(
        "https://example.test",
        lat,
        lon,
        "2025-07-01",
        "2025-07-01",
        OpenMeteo();
        request_get=request_get,
        retries=2,
        retry_delay=0.25,
        sleep_fn=x -> push!(sleep_calls, x)
    )

    @test attempts[] == 3
    @test sleep_calls == [0.25, 0.5]
    @test length(weather) == 2
end

@testset "OpenMeteo does not retry permanent HTTP status codes" begin
    attempts = Ref(0)
    request_get(url; status_exception=false) = begin
        attempts[] += 1
        PlantMeteo.HTTP.Response(400, PlantMeteo.JSON.json(Dict("reason" => "bad request")))
    end

    err = capture_error(() -> PlantMeteo.fetch_openmeteo(
        "https://example.test",
        lat,
        lon,
        "2025-07-01",
        "2025-07-01",
        OpenMeteo();
        segment="archive",
        request_get=request_get,
        retries=2,
        sleep_fn=_ -> nothing
    ))

    @test err isa PlantMeteo.OpenMeteoRequestError
    @test attempts[] == 1
    @test occursin("archive", sprint(showerror, err))
    @test occursin("HTTP 400", sprint(showerror, err))
end

@testset "OpenMeteo surfaces invalid JSON clearly" begin
    request_get(url; status_exception=false) = PlantMeteo.HTTP.Response(200, "{not-json")

    err = capture_error(() -> PlantMeteo.fetch_openmeteo(
        "https://example.test",
        lat,
        lon,
        "2025-07-01",
        "2025-07-01",
        OpenMeteo();
        request_get=request_get
    ))

    @test err isa PlantMeteo.OpenMeteoRequestError
    @test occursin("invalid JSON response", sprint(showerror, err))
end

@testset "OpenMeteo validates response schema" begin
    bad_payload = openmeteo_payload()
    delete!(bad_payload["hourly"], "surface_pressure")
    request_get(url; status_exception=false) = PlantMeteo.HTTP.Response(200, PlantMeteo.JSON.json(bad_payload))

    err = capture_error(() -> PlantMeteo.fetch_openmeteo(
        "https://example.test",
        lat,
        lon,
        "2025-07-01",
        "2025-07-01",
        OpenMeteo();
        request_get=request_get
    ))

    @test err isa PlantMeteo.OpenMeteoRequestError
    @test occursin("surface_pressure", sprint(showerror, err))
end

@testset "OpenMeteo archive data" begin
    period = [Dates.Date(2021, 12, 30), Dates.Date(2021, 12, 31)]
    w = get_forecast(OpenMeteo(), lat, lon, period; verbose=false)
    @test length(w) == 48 # 2 x 24 hours
    @test typeof(w) == TimeStepTable{Atmosphere}
    @test typeof(w.T) == Vector{Float64}
    @test keys(w) == vars
end

@testset "OpenMeteo historical forecast data" begin
    period = [Dates.today() - Dates.Day(200), Dates.today() - Dates.Day(199)]
    w = get_forecast(OpenMeteo(), lat, lon, period; verbose=false)
    @test length(w) == 48 # 2 x 24 hours
    @test typeof(w) == TimeStepTable{Atmosphere}
    @test typeof(w.T) == Vector{Float64}
    @test keys(w) == vars
end

@testset "OpenMeteo historical forecast and forecast data" begin
    period = [Dates.today() - Dates.Day(1), Dates.today()]
    params = OpenMeteo()
    w = get_forecast(params, lat, lon, period; verbose=false)
    @test length(w) == 48 # 2 x 24 hours
    @test typeof(w) == TimeStepTable{Atmosphere}
    @test typeof(w.T) == Vector{Float64}
    @test keys(w) == vars
    @test w[1].date == period[1]
    @test w[1].duration == Dates.Hour(1)
    @test w[end].date == Dates.DateTime(period[2]) + Dates.Hour(23)
end
