@testset "explicit weather import normalization" begin
    raw = (
        Rh=Union{Missing,Float64}[60.0, missing],
        P=Union{Missing,Float64}[1013.0, missing],
        T=[25.0, 26.0],
    )

    normalized = normalize_weather_import(
        raw;
        input_units=(Rh=:percent, P=:hPa),
    )

    @test normalized.data.Rh[1] ≈ 0.6
    @test ismissing(normalized.data.Rh[2])
    @test normalized.data.P[1] ≈ 101.3
    @test ismissing(normalized.data.P[2])
    @test normalized.data.T == raw.T
    @test raw.Rh[1] == 60.0
    @test raw.P[1] == 1013.0
    @test normalized.provenance == (
        input_units=(Rh=:percent, P=:hPa),
        output_units=(Rh=:fraction, P=:kPa),
        conversions=(
            (variable=:Rh, input_unit=:percent, output_unit=:fraction, scale=0.01),
            (variable=:P, input_unit=:hPa, output_unit=:kPa, scale=0.1),
        ),
    )

    partial_units = normalize_weather_import(raw; input_units=(Rh=:percent,))
    @test partial_units.data.Rh[1] ≈ 0.6
    @test ismissing(partial_units.data.Rh[2])
    @test isequal(partial_units.data.P, raw.P)
    @test partial_units.provenance.input_units == (Rh=:percent, P=:kPa)
    @test partial_units.provenance.conversions == (
        (variable=:Rh, input_unit=:percent, output_unit=:fraction, scale=0.01),
    )

    canonical = normalize_weather_import(raw)
    @test isequal(canonical.data, raw)
    @test isempty(canonical.provenance.conversions)

    pascals = normalize_weather_import((P=[101_300.0],); input_units=(P=:Pa,))
    @test pascals.data.P[1] ≈ 101.3

    @test_throws ArgumentError normalize_weather_import(raw; input_units=(RH=:percent,))
    @test_throws ArgumentError normalize_weather_import(raw; input_units=(Rh=:ratio,))
    @test_throws ArgumentError normalize_weather_import(raw; input_units=(Rh="percent",))
end
