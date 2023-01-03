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

@testset "OpenMeteo historical data" begin
    period = [Dates.today() - Dates.Day(200), Dates.today() - Dates.Day(199)]
    w = get_forecast(OpenMeteo(), lat, lon, period; verbose=false)
    @test length(w) == 48 # 2 x 24 hours
    @test typeof(w) == TimeStepTable{Atmosphere}
    @test typeof(w.T) == Vector{Float64}
    @test keys(w) == vars
end

@testset "OpenMeteo historical and forecast data" begin
    period = [Dates.today() - Dates.Day(197), Dates.today() - Dates.Day(196)]
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