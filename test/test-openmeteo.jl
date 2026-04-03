lat = 48.8566
lon = 2.3522

vars = (
    :date, :duration, :T, :Wind, :P, :Rh, :Precipitations, :Cₐ, :e,
    :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness, :Ri_SW_f, :Ri_PAR_f,
    :Ri_NIR_f, :Ri_TIR_f, :Ri_custom_f, :Ri_SW_f_direct,
    :Ri_SW_f_diffuse
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
            "temperature_2m" => "degC",
            "relativehumidity_2m" => "%",
            "precipitation" => "mm",
            "surface_pressure" => "hPa",
            "windspeed_10m" => "m/s",
            "shortwave_radiation" => "W/m2",
            "direct_radiation" => "W/m2",
            "diffuse_radiation" => "W/m2",
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

@testset "OpenMeteo retries transient failures" begin
    attempts = Ref(0)
    sleep_calls = Float64[]
    request_get(url; status_exception=false) = begin
        attempts[] += 1
        attempts[] < 3 && throw(PlantMeteo.HTTP.TimeoutError(1))
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
