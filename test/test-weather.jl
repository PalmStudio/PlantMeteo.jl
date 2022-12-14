
@testset "Weather function" begin
    atm_vec =
        [
            Atmosphere(T=20.0, Wind=1.0, P=101.3, Rh=0.65),
            Atmosphere(T=23.0, Wind=1.5, P=101.3, Rh=0.60),
            Atmosphere(T=25.0, Wind=3.0, P=101.3, Rh=0.55)
        ]
    metadata = (
        site="Test site",
        important_metadata="this is important and will be attached to our weather data"
    )

    # A Weather is now just a TimeStepTable
    @test Weather(atm_vec, metadata) == TimeStepTable(atm_vec, metadata)
end