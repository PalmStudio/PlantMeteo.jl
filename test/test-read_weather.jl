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

    # ARCHIMED-like date encoding: first row has date, following rows can omit it.
    tmp = mktempdir()
    archimed_like = joinpath(tmp, "meteo.csv")
    open(archimed_like, "w") do io
        write(
            io,
            """
            date;hour_start;hour_end;temperature;relativeHumidity;wind;clearness
            2016/06/12;08:30:00;09:00:00;25;60;1.0;0.6
            ;09:00:00;09:30:00;25;60;1.0;0.6
            ;09:30:00;10:00:00;25;60;1.0;0.6
            """
        )
    end

    meteo_archimed = read_weather(
        archimed_like,
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
        date_formats=(DateFormat("yyyy/mm/dd"), DateFormat("yyyy-mm-dd")),
        forward_fill_date=true,
    )
    @test meteo_archimed.date[1] == DateTime(2016, 6, 12, 8, 30, 0)
    @test meteo_archimed.date[2] == DateTime(2016, 6, 12, 9, 0, 0)
    @test meteo_archimed.date[3] == DateTime(2016, 6, 12, 9, 30, 0)
end;
