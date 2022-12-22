lat = 48.8566
lon = 2.3522

vars = (
    :date, :duration, :T, :Wind, :P, :Rh, :Precipitations, :Cₐ, :e,
    :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness, :Ri_SW_f, :Ri_PAR_f,
    :Ri_NIR_f, :Ri_TIR_f, :Ri_custom_f
)

# Create a fake API to test without calling external APIs
struct TestAPI <: PlantMeteo.AbstractAPI end

function PlantMeteo.get_forecast(params::TestAPI, lat, lon, period; verbose=true)
    TimeStepTable(
        [
            Atmosphere(
                date=DateTime(period[1]),
                duration=Hour(1),
                T=20.0,
                Wind=1.0,
                P=101.0,
                Rh=0.6,
            ),
            Atmosphere(
                date=DateTime(period[end]),
                duration=Hour(1),
                T=23.0,
                Wind=1.0,
                P=101.0,
                Rh=0.6,
            )],
        (
            latitude=lat,
            longitude=lon,
        )
    )
end

@testset "OpenMeteo forecast data" begin
    period = Dates.today():Dates.Day(1):Dates.today()+Dates.Day(1)
    api = TestAPI()
    sink = TimeStepTable

    w = get_weather(lat, lon, period; api=api, sink=sink)
    @test length(w) == 2 # 2 x 24 hours
    @test typeof(w) <: TimeStepTable{A} where {A<:Atmosphere}
    @test typeof(w.T) == Vector{Float64}
    @test keys(w) == vars
end