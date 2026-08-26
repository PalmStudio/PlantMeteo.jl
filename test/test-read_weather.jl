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
        # Metadata stays exactly as supplied even though the data column is
        # renamed from Re_SW_f to Ri_SW_f above.
        "use" => "Re_SW_f, clearness",
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

    custom_duration_file = joinpath(tmp, "custom_duration.csv")
    open(custom_duration_file, "w") do io
        write(
            io,
            """
            date;hour_start;hour_end;temperature;relativeHumidity;wind
            2016/06/12;08:00:00;09:00:00;25;60;1.0
            2016/06/12;09:00:00;10:00:00;26;62;1.1
            2016/06/12;10:00:00;11:00:00;27;64;1.2
            """
        )
    end

    duration_args = (
        :temperature => :T,
        :relativeHumidity => (x -> x ./ 100) => :Rh,
        :wind => :Wind,
    )

    meteo_constant_duration = read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=Minute(30),
    )
    @test meteo_constant_duration.duration == fill(Minute(30), 3)

    meteo_vector_duration = read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=[Minute(15), Minute(30), Minute(45)],
    )
    @test meteo_vector_duration.duration == [Minute(15), Minute(30), Minute(45)]

    meteo_function_duration = read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=data -> fill(Minute(20), length(data.date)),
    )
    @test meteo_function_duration.duration == fill(Minute(20), 3)

    meteo_scalar_function_duration = read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=data -> Minute(10),
    )
    @test meteo_scalar_function_duration.duration == fill(Minute(10), 3)

    duration_column_file = joinpath(tmp, "duration_column.csv")
    open(duration_column_file, "w") do io
        write(
            io,
            """
            date;hour_start;duration;temperature;relativeHumidity;wind
            2016/06/12;08:00:00;15;25;60;1.0
            2016/06/12;08:15:00;30;26;62;1.1
            2016/06/12;08:45:00;45;27;64;1.2
            """
        )
    end

    meteo_parsed_duration = read_weather(
        duration_column_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=Minute,
    )
    @test meteo_parsed_duration.duration == [Minute(15), Minute(30), Minute(45)]
    @test_throws ArgumentError read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=[Minute(15), Minute(30)],
    )
end;
