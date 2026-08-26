
@testset "Atmosphere structure" begin
    forced_date = Dates.DateTime("2021-09-15T16:24:00.929")

    @test_throws "Missing mandatory Atmosphere keyword argument(s): `T`, `Wind`, `Rh`" Atmosphere()
    @test_throws "Missing mandatory Atmosphere keyword argument(s): `Rh`" Atmosphere(T=25, Wind=5)
    @test_throws "Missing mandatory Atmosphere keyword argument(s): `T`" Atmosphere(Wind=5, Rh=0.3)

    # Testing Atmosphere with some random values:
    @test NamedTuple(Atmosphere(date=forced_date, T=25, Wind=5, Rh=0.3)) ==
          NamedTuple{
        (
        :date, :duration, :T, :Wind, :P, :Rh, :Precipitations,
        :Cₐ, :e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ
    )
    }(
        (
        DateTime("2021-09-15T16:24:00.929"), Second(1), 25.0, 5.0, 101.325,
        0.3, 0.0, 400.0, 0.9540587244435038, 3.180195748145013,
        2.2261370237015092, 1.1838896840018194, 2.441875e6,
        0.06757907523556121, 0.5455578187331258, 0.19009500927530176
    )
    )

    default_atmosphere = Atmosphere(T=25, Wind=5, Rh=0.3)
    @test !hasproperty(default_atmosphere, :clearness)
    @test !hasproperty(default_atmosphere, :Ri_SW_f)

    explicit_missing = Atmosphere(
        T=25,
        Wind=5,
        Rh=0.3,
        clearness=missing,
        Ri_SW_f=missing,
    )
    @test hasproperty(explicit_missing, :clearness)
    @test hasproperty(explicit_missing, :Ri_SW_f)
    @test ismissing(explicit_missing.clearness)
    @test ismissing(explicit_missing.Ri_SW_f)
    @test !hasproperty(explicit_missing, :Ri_PAR_f)

    # Testing error messages on recent versions of Julia only as format changed around 1.8
    if VERSION >= v"1.8"
        # Testing Rh with values given in %:
        @test_throws "Relative humidity (30) must be between 0 and 1" Atmosphere(T=25, Wind=5, Rh=30)
        @test_throws "Relative humidity (-0.1) must be between 0 and 1" Atmosphere(T=25, Wind=5, Rh=-0.1)
        @test_throws "Rh must be finite, got NaN" Atmosphere(T=25, Wind=5, Rh=NaN)
        @test Atmosphere(T=25, Wind=5, Rh=0.0).Rh == 0.0
        @test_throws "Wind speed (-1.0) must be non-negative" Atmosphere(T=25, Wind=-1.0, Rh=0.3)
        @test_throws "Wind must be finite, got Inf" Atmosphere(T=25, Wind=Inf, Rh=0.3)
        @test Atmosphere(T=25, Wind=0.0, Rh=0.3).Wind == 0.0
        @test_throws "T must be finite, got NaN" Atmosphere(T=NaN, Wind=5, Rh=0.3)
        @test Atmosphere(T=25, Wind=5, Rh=0.3, clearness=0.0).clearness == 0.0
        @test Atmosphere(T=25, Wind=5, Rh=0.3, Ri_SW_f=0.0).Ri_SW_f == 0.0
        @test_throws "clearness (-0.1) must be between 0 and 1" Atmosphere(T=25, Wind=5, Rh=0.3, clearness=-0.1)
        @test_throws "clearness must be finite, got NaN" Atmosphere(T=25, Wind=5, Rh=0.3, clearness=NaN)

        @test_throws "Air pressure (10.0) is not in the 85-110 kPa earth range" Atmosphere(T=25, Wind=5, Rh=0.3, P=10.0)
        @test_throws "Air pressure (1003.0) is not in the 85-110 kPa earth range" Atmosphere(T=25, Wind=5, Rh=0.3, P=1003.0)
        @test_throws "P must be finite, got Inf" Atmosphere(T=25, Wind=5, Rh=0.3, P=Inf)
        @test_throws "Air pressure (85.0) is not in the 85-110 kPa earth range" Atmosphere(T=25, Wind=5, Rh=0.3, P=85.0)
        @test_throws "Air pressure (110.0) is not in the 85-110 kPa earth range" Atmosphere(T=25, Wind=5, Rh=0.3, P=110.0)

        @test_throws "Ri_SW_f must be finite, got Inf" Atmosphere(T=25, Wind=5, Rh=0.3, Ri_SW_f=Inf)
        @test_throws "Ri_SW_f (-1.0) must be non-negative" Atmosphere(T=25, Wind=5, Rh=0.3, Ri_SW_f=-1.0)

        unchecked = Atmosphere(
            T=25,
            Wind=-1.0,
            Rh=30.0,
            P=1003.0,
            clearness=Inf,
            Ri_SW_f=-1.0,
            check=false,
        )
        @test unchecked.Wind == -1.0
        @test unchecked.Rh == 30.0
        @test unchecked.P == 1003.0
        @test unchecked.clearness == Inf
        @test unchecked.Ri_SW_f == -1.0
    end
end;
