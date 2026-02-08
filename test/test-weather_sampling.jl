using Test
using Dates

@testset "weather sampling" begin
    base_date = Dates.DateTime(2025, 1, 1, 0, 0, 0)
    meteo = Weather([
        Atmosphere(date=base_date + Dates.Hour(0), duration=Dates.Hour(1), T=10.0, Wind=1.0, Rh=0.50, P=100.0, Ri_SW_f=100.0, custom_var=1.0),
        Atmosphere(date=base_date + Dates.Hour(1), duration=Dates.Hour(1), T=20.0, Wind=1.0, Rh=0.60, P=100.0, Ri_SW_f=200.0, custom_var=2.0),
        Atmosphere(date=base_date + Dates.Hour(2), duration=Dates.Hour(1), T=30.0, Wind=1.0, Rh=0.70, P=100.0, Ri_SW_f=300.0, custom_var=3.0),
        Atmosphere(date=base_date + Dates.Hour(3), duration=Dates.Hour(1), T=40.0, Wind=1.0, Rh=0.80, P=100.0, Ri_SW_f=400.0, custom_var=4.0),
    ])

    prepared = prepare_weather_sampler(meteo)
    spec2 = MeteoSamplingSpec(2.0, 1.0)

    s1 = sample_weather(prepared, 1; spec=spec2)
    @test s1.T == 10.0
    @test s1.Tmin == 10.0
    @test s1.Tmax == 10.0
    @test s1.Rh == 0.5
    @test s1.Ri_SW_f == 100.0
    @test isapprox(s1.Ri_SW_q, 0.36; atol=1.0e-9)

    s3 = sample_weather(prepared, 3; spec=spec2)
    @test s3.T == 25.0
    @test s3.Tmin == 20.0
    @test s3.Tmax == 30.0
    @test s3.Rh == 0.65
    @test s3.Rhmin == 0.6
    @test s3.Rhmax == 0.7
    @test s3.Ri_SW_f == 250.0
    @test isapprox(s3.Ri_SW_q, 1.8; atol=1.0e-9)
    @test s3.duration == Dates.Hour(2)

    # Lazy cache should return the same object for the same query.
    s3_cached = sample_weather(prepared, 3; spec=spec2)
    @test s3_cached === s3

    # Custom transform override with radiation quantity on Ri_SW_f itself.
    custom = (
        Ri_SW_f=(source=:Ri_SW_f, reducer=RadiationEnergy()),
        custom_peak=(source=:custom_var, reducer=MaxReducer()),
    )
    s3_custom = sample_weather(prepared, 3; spec=spec2, transforms=custom)
    @test isapprox(s3_custom.Ri_SW_f, 1.8; atol=1.0e-9)
    @test s3_custom.custom_peak == 3.0

    # Precompute path for repeated simulations.
    tables = materialize_weather(prepared; specs=[spec2])
    @test haskey(tables, spec2)
    @test length(tables[spec2]) == length(meteo)
    @test tables[spec2][3].T == s3.T

    # Default transform mode switching: radiation in quantity on *_f targets.
    prepared_energy = prepare_weather_sampler(meteo; transforms=default_sampling_transforms(radiation_mode=:energy_sum))
    s3_energy = sample_weather(prepared_energy, 3; spec=spec2)
    @test isapprox(s3_energy.Ri_SW_f, 1.8; atol=1.0e-9)

    # Reducer types can be provided directly (without symbols).
    typed = (
        T=MeanWeighted(),
        Tmax=(source=:T, reducer=MaxReducer()),
        Tsum=(source=:T, reducer=SumReducer()),
    )
    s3_typed = sample_weather(prepared, 3; spec=spec2, transforms=typed)
    @test s3_typed.T == 25.0
    @test s3_typed.Tmax == 30.0
    @test s3_typed.Tsum == 50.0

    # Symbol reducers are intentionally unsupported in the new API.
    @test_throws "Unsupported reducer value" sample_weather(prepared, 3; spec=spec2, transforms=(; T=:weighted_mean))
end

@testset "calendar window sampling" begin
    base = Dates.DateTime(2025, 1, 1, 0, 0, 0)

    day1 = [
        Atmosphere(
            date=base + Dates.Hour(i - 1),
            duration=Dates.Hour(1),
            T=float(i),
            Wind=1.0,
            Rh=0.50,
            P=100.0,
            Ri_SW_f=100.0
        )
        for i in 1:24
    ]
    day2 = [
        Atmosphere(
            date=base + Dates.Hour(24 + i - 1),
            duration=Dates.Hour(1),
            T=float(100 + i),
            Wind=1.0,
            Rh=0.60,
            P=100.0,
            Ri_SW_f=200.0
        )
        for i in 1:24
    ]
    meteo = Weather(vcat(day1, day2))
    prepared = prepare_weather_sampler(meteo)

    spec_day_current = MeteoSamplingSpec(
        1.0;
        window=CalendarWindow(:day; anchor=:current_period, week_start=1, completeness=:allow_partial)
    )
    s2 = sample_weather(prepared, 2; spec=spec_day_current)
    @test s2.T == 12.5
    @test s2.Tmin == 1.0
    @test s2.Tmax == 24.0
    @test isapprox(s2.Ri_SW_q, 8.64; atol=1.0e-9)

    s26 = sample_weather(prepared, 26; spec=spec_day_current)
    @test s26.T == 112.5
    @test s26.Tmin == 101.0
    @test s26.Tmax == 124.0
    @test isapprox(s26.Ri_SW_q, 17.28; atol=1.0e-9)

    spec_day_prev = MeteoSamplingSpec(
        1.0;
        window=CalendarWindow(:day; anchor=:previous_complete_period, week_start=1, completeness=:allow_partial)
    )
    s30_prev = sample_weather(prepared, 30; spec=spec_day_prev)
    @test s30_prev.T == 12.5
    @test s30_prev.Tmin == 1.0
    @test s30_prev.Tmax == 24.0

    spec_day_prev_strict = MeteoSamplingSpec(
        1.0;
        window=CalendarWindow(:day; anchor=:previous_complete_period, week_start=1, completeness=:strict)
    )
    @test_throws "No period available" sample_weather(prepared, 5; spec=spec_day_prev_strict)

    meteo_incomplete = Weather(day1[1:12])
    prepared_incomplete = prepare_weather_sampler(meteo_incomplete)
    spec_day_strict = MeteoSamplingSpec(
        1.0;
        window=CalendarWindow(:day; anchor=:current_period, week_start=1, completeness=:strict)
    )
    @test_throws "Incomplete day period" sample_weather(prepared_incomplete, 3; spec=spec_day_strict)
end
