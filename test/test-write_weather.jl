@testset "write_weather" begin
    file = joinpath(dirname(dirname(pathof(PlantMeteo))), "test", "data", "meteo.csv")
    meteo = read_weather(
        file,
        :temperature => :T,
        :relativeHumidity => :Rh,
        :wind => :Wind,
        :atmosphereCO2_ppm => :Cₐ,
        date_format=DateFormat("yyyy/mm/dd"),
        input_units=(Rh=:percent,),
    )

    mktemp() do path, io
        write_weather(path, meteo)
        meteo2 = read_weather(path, duration=Dates.Minute)
        @test DataFrames.DataFrame(meteo) == DataFrames.DataFrame(meteo2)

        first_history = metadata(meteo, :import_normalization)
        roundtrip_history = metadata(meteo2, :import_normalization)
        @test length(first_history) == 1
        @test length(roundtrip_history) == 2
        @test roundtrip_history[1] == first_history[1]
        @test roundtrip_history[2]["input_units"] ==
              Dict{String,Any}("Rh" => "fraction", "P" => "kPa")
        @test isempty(roundtrip_history[2]["conversions"])
        @test all(record -> record isa AbstractDict, roundtrip_history)
    end

    @testset "write all variables when vars=nothing" begin
        df = PlantMeteo.prepare_weather(meteo; vars=nothing)
        @test sort(collect(propertynames(df))) == sort(collect(propertynames(meteo)))
    end

    @testset "optional forcing schema round trip" begin
        base_date = DateTime(2025, 7, 1, 12)
        no_optional = Weather([
            Atmosphere(date=base_date, duration=Hour(1), T=24.0, Wind=0.0, Rh=0.0, P=101.3),
            Atmosphere(date=base_date + Hour(1), duration=Hour(1), T=25.0, Wind=1.0, Rh=0.5, P=101.3),
        ])
        @test !(:Ri_SW_f in keys(no_optional))
        @test !(:clearness in keys(no_optional))

        mktemp() do path, io
            write_weather(path, no_optional; duration=Dates.Second)
            reread = read_weather(path; duration=Dates.Second)
            @test !(:Ri_SW_f in keys(reread))
            @test !(:clearness in keys(reread))
        end

        partial_optional = Weather([
            Atmosphere(date=base_date, duration=Hour(1), T=24.0, Wind=1.0, Rh=0.5, P=101.3),
            Atmosphere(
                date=base_date + Hour(1),
                duration=Hour(1),
                T=25.0,
                Wind=1.0,
                Rh=0.5,
                P=101.3,
                Ri_SW_f=250.0,
            ),
        ])
        @test ismissing(partial_optional[1].Ri_SW_f)
        @test partial_optional[2].Ri_SW_f == 250.0

        mktemp() do path, io
            write_weather(path, partial_optional; duration=Dates.Second)
            reread = read_weather(path; duration=Dates.Second)
            @test :Ri_SW_f in keys(reread)
            @test ismissing(reread[1].Ri_SW_f)
            @test reread[2].Ri_SW_f == 250.0
            radiation_index = findfirst(==(:Ri_SW_f), keys(reread))
            @test Tables.schema(reread).types[radiation_index] == Union{Missing,Float64}
        end
    end
end
