@testset "write_weather" begin
    file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")
    meteo = read_weather(
        file,
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
        :atmosphereCO2_ppm => :Cₐ,
        date_format=DateFormat("yyyy/mm/dd"),
    )

    mktemp() do path, io
        write_weather(path, meteo)
        meteo2 = read_weather(path, duration=Dates.Minute)
        @test DataFrames.DataFrame(meteo) == DataFrames.DataFrame(meteo2)
    end
end