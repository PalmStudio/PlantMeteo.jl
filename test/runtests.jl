using PlantMeteo
using Test
using Dates, Statistics
using Tables, DataFrames
using Documenter # for doctests

@testset "Test PlantMeteo" begin
    @testset "Atmosphere" begin
        include("test-atmosphere.jl")
    end

    @testset "weather()" begin
        include("test-weather.jl")
    end

    @testset "read_weather()" begin
        include("test-read_weather.jl")
    end

    @testset "write_weather()" begin
        include("test-write_weather.jl")
    end

    @testset "TimeStepRow" begin
        include("test-TimeStepRow.jl")
    end

    @testset "TimeStepTable" begin
        include("test-TimeStepTable.jl")
    end

    # @testset "transform" begin
    #     include("test-transform.jl")
    # end

    @testset "Generic meteo API" begin
        include("test-genericAPI.jl")
    end

    @testset "OpenMeteo" begin
        include("test-openmeteo.jl")
    end

    @testset "to_daily()" begin
        include("test-to_daily.jl")
    end

    @testset "Doctests" begin
        DocMeta.setdocmeta!(PlantMeteo, :DocTestSetup, :(using PlantMeteo, Dates); recursive=true)

        # Testing the doctests, i.e. the examples in the docstrings marked with jldoctest:
        doctest(PlantMeteo; manual=false)
    end
end