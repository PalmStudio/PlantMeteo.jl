using PlantMeteo
using Test
using Dates
using Tables, DataFrames

@testset "Atmosphere" begin
    include("test-atmosphere.jl")
end

@testset "weather()" begin
    include("test-weather.jl")
end

@testset "read_weather()" begin
    include("test-read_weather.jl")
end

@testset "TimeStepTable" begin
    include("test-TimeStepTable.jl")
end