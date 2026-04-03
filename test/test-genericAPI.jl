lat = 48.8566
lon = 2.3522

vars = (
    :date, :duration, :T, :Wind, :P, :Rh, :Precipitations, :Cₐ, :e,
    :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness, :Ri_SW_f, :Ri_PAR_f,
    :Ri_NIR_f, :Ri_TIR_f, :Ri_custom_f
)

@testset "Generic API with DemoAPI" begin
    period = Dates.today():Dates.Day(1):Dates.today()+Dates.Day(1)
    api = PlantMeteo.DemoAPI()
    sink = TimeStepTable

    w = get_weather(lat, lon, period; api=api, sink=sink)
    @test length(w) == 48 # 2 x 24 hours
    @test typeof(w) <: TimeStepTable{A} where {A<:Atmosphere}
    @test typeof(w.T) == Vector{Float64}
    @test keys(w) == vars
end

@testset "Generic API sink" begin
    period = Dates.today():Dates.Day(1):Dates.today()+Dates.Day(1)
    api = PlantMeteo.DemoAPI()
    sink = DataFrame

    w = get_weather(lat, lon, period; api=api, sink=sink)
    @test typeof(w) <: DataFrame
    @test nrow(w) == 48 # 2 x 24 hours
    @test names(w) == [string.(vars)...]
end


@testset "to_daily" begin
    period = [Dates.today(), Dates.today() + Dates.Day(2)]
    api = PlantMeteo.DemoAPI()
    w = get_weather(lat, lon, period; api=api, sink=TimeStepTable)
    w_daily = to_daily(w)

    w_dates = unique(Dates.Date.(w.date))
    @test length(w_dates) == 3
    @test w_dates == w_daily.date

    @test w_daily.year == [Dates.year(w.date[Dates.Date.(w.date).==i][1]) for i in w_dates]
    @test w_daily.duration == [sum(w.duration[Dates.Date.(w.date).==i]) for i in w_dates]
    @test w_daily.T ≈ [Statistics.mean(w.T[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
    @test w_daily.Tmin ≈ [minimum(w.T[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
    @test w_daily.Tmax ≈ [maximum(w.T[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
    @test w_daily.Wind ≈ [Statistics.mean(w.Wind[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
    @test w_daily.P ≈ [Statistics.mean(w.P[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
    @test w_daily.Precipitations ≈ [sum(w.Precipitations[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
    @test w_daily.Rh ≈ [Statistics.mean(w.Rh[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
end


@testset "to_daily (with user transformations)" begin
    period = Dates.today():Dates.Day(1):Dates.today()+Dates.Day(2)
    api = PlantMeteo.DemoAPI()
    w = get_weather(lat, lon, period; api=api, sink=TimeStepTable)
    w_daily = to_daily(
        w,
        :T => minimum => :Tmin, # override default transformation with same transformation
        :T => (x -> maximum(x) .+ 0.1) => :Tmax, # override default transformation with different transformation
        :T => maximum, # override default transformation but not renaming again (makes T_maximum)
        :T => (x -> sum(max.(x .- 15.0, 0.0))) => :GDD, # add a new variable
    )

    # With user transformations:
    w_dates = unique(Dates.Date.(w.date))
    @test length(w_dates) == 3
    @test w_dates == w_daily.date

    @test w_daily.Tmin ≈ [minimum(w.T[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
    @test w_daily.Tmax ≈ [maximum(w.T[Dates.Date.(w.date).==i]) + 0.1 for i in w_dates] atol = 1.0e-6
    @test w_daily.T_maximum ≈ [maximum(w.T[Dates.Date.(w.date).==i]) for i in w_dates] atol = 1.0e-6
    @test w_daily.GDD ≈ [sum(max.(w.T[Dates.Date.(w.date).==i] .- 15.0, 0.0)) for i in w_dates] atol = 1.0e-6
end
