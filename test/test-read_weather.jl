# Test reading the meteo:

file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")
var_names = Dict(:temperature => :T, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)

@testset "read_weather()" begin
    meteo = read_weather(
        file,
        :temperature => :T,
        :relativeHumidity => :Rh,
        :wind => :Wind,
        :atmosphereCO2_ppm => :Cₐ,
        :Re_SW_f => :Ri_SW_f,
        date_format=DateFormat("yyyy/mm/dd"),
        input_units=(Rh=:percent,),
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
        "import_normalization" => Any[
            Dict{String,Any}(
                "schema" => "PlantMeteo.import-normalization.v1",
                "input_units" => Dict{String,Any}("Rh" => "percent", "P" => "kPa"),
                "output_units" => Dict{String,Any}("Rh" => "fraction", "P" => "kPa"),
                "conversions" => [
                    Dict{String,Any}(
                        "variable" => "Rh",
                        "input_unit" => "percent",
                        "output_unit" => "fraction",
                        "scale" => 0.01,
                    ),
                ],
            ),
        ],
    )
    @test meteo.Rh ≈ [0.6, 0.62, 0.58]

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
        :relativeHumidity => :Rh,
        :wind => :Wind,
        date_formats=(DateFormat("yyyy/mm/dd"), DateFormat("yyyy-mm-dd")),
        forward_fill_date=true,
        input_units=(Rh=:percent,),
    )
    @test meteo_archimed.date[1] == DateTime(2016, 6, 12, 8, 30, 0)
    @test meteo_archimed.date[2] == DateTime(2016, 6, 12, 9, 0, 0)
    @test meteo_archimed.date[3] == DateTime(2016, 6, 12, 9, 30, 0)

    legacy_units_file = joinpath(tmp, "legacy_units.csv")
    open(legacy_units_file, "w") do io
        write(
            io,
            """
            date;hour_start;hour_end;T;Wind;Rh;P
            2016/06/12;08:00:00;09:00:00;25;1.0;60;1013
            """
        )
    end
    meteo_legacy_units = read_weather(
        legacy_units_file;
        date_format=DateFormat("yyyy/mm/dd"),
        input_units=(Rh=:percent, P=:hPa),
    )
    @test meteo_legacy_units.Rh[1] ≈ 0.6
    @test meteo_legacy_units.P[1] ≈ 101.3
    legacy_history = metadata(meteo_legacy_units, :import_normalization)
    @test length(legacy_history) == 1
    @test legacy_history[1]["conversions"] == [
        Dict{String,Any}(
            "variable" => "Rh",
            "input_unit" => "percent",
            "output_unit" => "fraction",
            "scale" => 0.01,
        ),
        Dict{String,Any}(
            "variable" => "P",
            "input_unit" => "hPa",
            "output_unit" => "kPa",
            "scale" => 0.1,
        ),
    ]
    @test_throws "Relative humidity (60) must be between 0 and 1" read_weather(
        legacy_units_file;
        date_format=DateFormat("yyyy/mm/dd"),
    )

    provenance_file = joinpath(tmp, "provenance.csv")
    upstream_record = Dict{String,Any}(
        "schema" => "upstream.weather-normalization.v1",
        "note" => "preserve exactly",
    )
    PlantMeteo.write_weather_(
        provenance_file,
        (
            date=["2025-07-01T12:00:00.000"],
            duration=[3600],
            T=[25.0],
            Wind=[1.0],
            Rh=[0.5],
            P=[101.3],
        );
        metadata_=(import_normalization=Any[upstream_record],),
    )
    provenance_weather = read_weather(provenance_file; duration=Dates.Second)
    provenance_history = metadata(provenance_weather, :import_normalization)
    @test length(provenance_history) == 2
    @test provenance_history[1] == upstream_record
    @test provenance_history[2]["schema"] == "PlantMeteo.import-normalization.v1"
    @test isempty(provenance_history[2]["conversions"])

    scalar_provenance_file = joinpath(tmp, "scalar-provenance.csv")
    PlantMeteo.write_weather_(
        scalar_provenance_file,
        (
            date=["2025-07-01T12:00:00.000"],
            duration=[3600],
            T=[25.0],
            Wind=[1.0],
            Rh=[0.5],
            P=[101.3],
        );
        metadata_=(import_normalization="old importer: units unknown",),
    )
    scalar_provenance = read_weather(scalar_provenance_file; duration=Dates.Second)
    scalar_history = metadata(scalar_provenance, :import_normalization)
    @test scalar_history isa Vector{Dict{String,Any}}
    @test scalar_history[1] == Dict{String,Any}(
        "schema" => "PlantMeteo.import-normalization.legacy-source.v1",
        "source_value" => "old importer: units unknown",
    )

    scalar_roundtrip_file = joinpath(tmp, "scalar-provenance-roundtrip.csv")
    write_weather(scalar_roundtrip_file, scalar_provenance; duration=Dates.Second)
    scalar_roundtrip = read_weather(scalar_roundtrip_file; duration=Dates.Second)
    roundtrip_scalar_history = metadata(scalar_roundtrip, :import_normalization)
    @test roundtrip_scalar_history isa Vector{Dict{String,Any}}
    @test roundtrip_scalar_history[1] == scalar_history[1]
    @test all(record -> record isa Dict{String,Any}, roundtrip_scalar_history)

    empty_header_file = joinpath(tmp, "empty-header.csv")
    open(empty_header_file, "w") do io
        write(
            io,
            "#'\ndate,duration,T,Wind,Rh,P\n2025-07-01T12:00:00.000,3600,25,1,0.5,101.3\n",
        )
    end
    empty_header_weather = read_weather(empty_header_file; duration=Dates.Second)
    @test length(empty_header_weather) == 1

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
        :relativeHumidity => :Rh,
        :wind => :Wind,
    )

    meteo_constant_duration = read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=Minute(30),
        input_units=(Rh=:percent,),
    )
    @test meteo_constant_duration.duration == fill(Minute(30), 3)

    meteo_vector_duration = read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=[Minute(15), Minute(30), Minute(45)],
        input_units=(Rh=:percent,),
    )
    @test meteo_vector_duration.duration == [Minute(15), Minute(30), Minute(45)]

    meteo_function_duration = read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=data -> fill(Minute(20), length(data.date)),
        input_units=(Rh=:percent,),
    )
    @test meteo_function_duration.duration == fill(Minute(20), 3)

    meteo_scalar_function_duration = read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=data -> Minute(10),
        input_units=(Rh=:percent,),
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
        input_units=(Rh=:percent,),
    )
    @test meteo_parsed_duration.duration == [Minute(15), Minute(30), Minute(45)]
    @test_throws ArgumentError read_weather(
        custom_duration_file,
        duration_args...,
        date_format=DateFormat("yyyy/mm/dd"),
        duration=[Minute(15), Minute(30)],
        input_units=(Rh=:percent,),
    )
end;
