# This test file is not used anymore. See src/computations/transform_and_select.jl.

file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")

@testset "transform()" begin
    data, metadata = PlantMeteo.read_weather_(file)
    date_format = Dates.DateFormat("yyyy/mm/dd")

    meteo = PlantMeteo.transform(
        data,
        :temperature => :T, # rename variable
        :relativeHumidity => (x -> x ./ 100) => :Rh, # compute new variable
        :wind => :Wind, # rename also 
        :atmosphereCO2_ppm => :Cₐ, # same 
        :Re_SW_f, # keep variable
        (x -> PlantMeteo.compute_date(x, date_format)) => :date,
        (x -> PlantMeteo.compute_duration(x)) => :duration,
    )

    @test meteo[1] == (
        wind=1.0, atmosphereCO2_ppm=380.0, Re_SW_f=500.0, duration=Dates.Minute(30), Rh=0.6, Cₐ=380.0,
        hour_end=Dates.Time(12, 30), temperature=25.0, relativeHumidity=60.0, clearness=0.75,
        Wind=1.0, T=25.0, hour_start=Dates.Time(12), date=Dates.DateTime("2016-06-12T12:00:00")
    )
    @test length(meteo) == 3
end;
