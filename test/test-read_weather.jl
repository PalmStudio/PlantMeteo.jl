# Test reading the meteo:

file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")
var_names = Dict(:temperature => :T, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)

@testset "read_weather()" begin
    meteo = read_weather(
        file,
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
        :atmosphereCO2_ppm => :Cₐ,
        :Re_SW_f => :Ri_SW_f,
        date_format=DateFormat("yyyy/mm/dd")
    )

    @test typeof(meteo) <: TimeStepTable
    @test PlantMeteo.metadata(meteo) == Dict{String,Any}(
        "name" => "Aquiares",
        "latitude" => 15.0,
        "altitude" => 100.0,
        "use" => [:clearness],
        "file" => file,
    )
end;
