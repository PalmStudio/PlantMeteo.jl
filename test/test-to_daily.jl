@testset "to_daily" begin
    lat = 48.8566
    lon = 2.3522
    period = Dates.today():Dates.Day(1):Dates.today()+Dates.Day(1)
    w = get_weather(lat, lon, period, sink=DataFrame)
    @test nrow(w) == 48 # 2 x 24 hours
    @test_nowarn to_daily(w)
    w_day = to_daily(w)
    @test nrow(w_day) == 2

    # Testing temperature:
    @test hasproperty(w_day, :Tmin)
    @test hasproperty(w_day, :Tmax)
    @test w_day.Tmin[1] == minimum(w.T[1:24])
    @test w_day.Tmax[1] == maximum(w.T[1:24])
    @test w_day.Tmin[2] == minimum(w.T[25:48])
    @test w_day.T[2] ≈ mean(w.T[25:48])

    # Testing radiation:
    @test hasproperty(w_day, :Ri_SW_f)
    @test w_day.Ri_SW_f[1] ≈ sum(w.Ri_SW_f[1:24] .* 60.0 .* 60) * 1e-6
    @test w_day.Ri_PAR_f[1] ≈ sum(w.Ri_PAR_f[1:24] .* 60.0 .* 60) * 1e-6
    @test w_day.Ri_NIR_f[1] ≈ sum(w.Ri_NIR_f[1:24] .* 60.0 .* 60) * 1e-6

    # Test new transformations:
    w_day = to_daily(w, :T => mean => :Tmean)
    @test hasproperty(w_day, :Tmean)
    @test w_day.Tmean[1] ≈ mean(w.T[1:24])
    @test w_day.Tmean[2] ≈ mean(w.T[25:48])

    # Test changing default transformations:
    w_day = to_daily(w, :T => (x -> 1.0) => :Tmin, :T => (x -> 2.0) => :Tmax)
    @test hasproperty(w_day, :Tmin)
    @test hasproperty(w_day, :Tmax)
    @test w_day.Tmin[1] == 1.0
    @test w_day.Tmax[1] == 2.0
end