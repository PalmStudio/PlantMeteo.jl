
@testset "Atmosphere structure" begin
    forced_date = Dates.DateTime("2021-09-15T16:24:00.929")

    # Testing Atmosphere with some random values:
    @test NamedTuple(Atmosphere(date=forced_date, T=25, Wind=5, Rh=0.3)) ==
          NamedTuple{
        (
        :date, :duration, :T, :Wind, :P, :Rh, :Precipitations,
        :Cₐ, :e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness,
        :Ri_SW_f, :Ri_PAR_f, :Ri_NIR_f, :Ri_TIR_f, :Ri_custom_f
    )
    }(
        (
        DateTime("2021-09-15T16:24:00.929"), Second(1), 25.0, 5.0, 101.325,
        0.3, 0.0, 400.0, 0.9540587244435038, 3.180195748145013,
        2.2261370237015092, 1.1838896840018194, 2.441875e6,
        0.06757907523556121, 0.5455578187331258, 0.19009500927530176,
        Inf, Inf, Inf, Inf, Inf, Inf
    )
    )

    # Testing error messages on recent versions of Julia only as format changed around 1.8
    if VERSION >= v"1.8"
        # Testing Rh with values given in %:
        @test_throws "Relative humidity (30) must be between 0 and 1" Atmosphere(T=25, Wind=5, Rh=30)

        @test_throws "Air pressure (10.0) is not in the 87-110 kPa earth range" Atmosphere(T=25, Wind=5, Rh=0.3, P=10.0)
        @test_throws "Air pressure (1003.0) is not in the 87-110 kPa earth range" Atmosphere(T=25, Wind=5, Rh=0.3, P=1003.0)
        @test_logs (:warn, "P (1003.0) should be in kPa (i.e. 101.325 kPa at sea level), please consider converting it") Atmosphere(T=25, Wind=5, Rh=0.3, P=1003.0, check=false)
    end
end;
