"""
    Weather(D <: AbstractArray{<:AbstractAtmosphere}[, S])
    Weather(df::DataFrame[, mt])

Defines the weather, *i.e.* the local conditions of the Atmosphere for one or more time-steps.
Each time-step is described using the [`Atmosphere`](@ref) structure.

The simplest way to instantiate a `Weather` is to use a `DataFrame` as input.

The `DataFrame` should be formated such as each row is an observation for a given time-step
and each column is a variable. The column names should match exactly the field names of the
[`Atmosphere`](@ref) structure, `i.e.`:

```@example
fieldnames(Atmosphere)
```

## See also

- the [`Atmosphere`](@ref) structure
- the [`read_weather`](@ref) function to read Archimed-formatted meteorology data.

## Examples

```julia
# Example of weather data defined by hand (cumbersome):
w = Weather(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ],
    (
        site = "Test site",
        important_metadata = "this is important and will be attached to our weather data"
    )
)

# Example using a DataFrame, that you would usually import from a file:
using CSV, DataFrames
file = joinpath(dirname(dirname(pathof(PlantBiophysics))),"test","inputs","meteo.csv")
df = CSV.read(file, DataFrame; header=5, datarow = 6)
# Select and rename the variables:
select!(df, :date, :VPD, :temperature => :T, :relativeHumidity => :Rh, :wind => :Wind, :atmosphereCO2_ppm => :Cₐ)
df[!,:duration] .= 1800 # Add the time-step duration, 30min

# Make the weather, and add some metadata:
Weather(df, (site = "Aquiares", file = file))
```
"""
struct Weather{D<:AbstractArray{<:AbstractAtmosphere},S<:NamedTuple}
    data::D
    metadata::S
end

function Weather(df::T) where {T<:AbstractArray{<:AbstractAtmosphere}}
    Weather(df, NamedTuple())
end

function Weather(df::DataFrames.DataFrame, mt::S) where {S<:NamedTuple}
    Weather([Atmosphere(; i...) for i in eachrow(df)], mt)
end

function Weather(df::DataFrames.DataFrame, dict::S) where {S<:AbstractDict}
    # There must be a better way for transforming a Dict into a Status...
    Weather(df, NamedTuple{Tuple(Symbol.(keys(dict)))}(values(dict)))
end

function Weather(df::DataFrames.DataFrame)
    Weather(df, NamedTuple())
end

function Base.show(io::IO, n::Weather)
    printstyled(io, "Weather data.\n", bold=true, color=:green)
    printstyled(io, "Metadata: `$(n.metadata)`.\n", color=:cyan)
    printstyled(io, "Data:\n", color=:green)
    # :normal, :default, :bold, :black, :blink, :blue, :cyan, :green, :hidden, :light_black, :light_blue, :light_cyan, :light_green, :light_magenta, :light_red, :light_yellow, :magenta, :nothing, :red,
    #   :reverse, :underline, :white, or :yellow
    print(io, DataFrames.DataFrame(n))
    return nothing
end

# Base.getindex(w::Weather, i::Integer) = w.data[i]
# Base.getindex(w::Weather, s::Symbol) = [getproperty(i, s) for i in w.data]
Base.length(w::Weather) = length(w.data)

###### Tables.jl interface ######

Tables.istable(::Type{Weather{D,S}}) where {D,S} = true

# Keys should be the same between Weather so we only need the ones from the first timestep
Base.keys(w::Weather) = keys(getfield(w, :data)[1])
names(w::Weather) = keys(w)
# matrix(w::Weather) = reduce(hcat, [[i...] for i in w])'

function Tables.schema(m::Weather{D,S}) where {D<:AbstractAtmosphere,S}
    Tables.Schema(names(m), DataType[i.types[1] for i in D.parameters[2]])
end

Tables.rowaccess(::Type{<:Weather}) = true

function Tables.rows(t::Weather)
    return [i for i in getfield(A, :data)]
end

Base.eltype(::Type{Weather{D,S}}) where {D,S} = D

function Base.length(w::Weather{D,S}) where {D,S}
    length(getfield(w, :data))
end

Tables.columnnames(w::Weather) = names(w)

# Iterate over all time-steps in a Weather object.
Base.iterate(t::Weather{D,S}, st=1) where {D,S} = st > length(t) ? nothing : (t[st], st + 1)
Base.size(t::Weather{D,S}, dim=1) where {D,S} = dim == 1 ? length(t) : length(names(t))

function Tables.getcolumn(row::AbstractAtmosphere, i::Int)
    return row[i]
end
Tables.getcolumn(row::AbstractAtmosphere, nm::Symbol) = getproperty(row, nm)
Tables.columnnames(row::AbstractAtmosphere) = keys(row)

##### Indexing and setting:

# Indexing a Weather object with the dot syntax returns values of all time-steps for a
# variable (e.g. `w.Rh`).
function Base.getproperty(w::Weather, key::Symbol)
    getproperty(Tables.columns(w), key)
end

# Indexing with a Symbol extracts the variable (same as getproperty):
function Base.getindex(w::Weather, index::Symbol)
    getproperty(w, index)
end

@inline function Base.getindex(w::Weather, row_ind::Integer, col_ind::Integer)
    rows = Tables.rows(w)
    @boundscheck begin
        if col_ind < 1 || col_ind > length(keys(w))
            throw(BoundsError(w, (row_ind, col_ind)))
        end
        if row_ind < 1 || row_ind > length(w)
            throw(BoundsError(w, (row_ind, col_ind)))
        end
    end
    return @inbounds rows[row_ind][col_ind]
end

# Indexing a Weather in one dimension only gives the row (e.g. `w[1] == w[1,:]`)
@inline function Base.getindex(w::Weather, i::Integer)
    rows = Tables.rows(w)
    @boundscheck begin
        if i < 1 || i > length(w)
            throw(BoundsError(w, i))
        end
    end

    return @inbounds rows[i]
end

# Indexing a Weather with a colon (e.g. `w[1,:]`) gives all values in column.
@inline function Base.getindex(w::Weather, row_ind::Integer, ::Colon)
    return getindex(w, row_ind)
end

# Indexing a Weather with a colon (e.g. `w[:,1]`) gives all values in the row.
@inline function Base.getindex(w::Weather, ::Colon, col_ind::Integer)
    return getproperty(Tables.columns(w), col_ind)
end

# Pushing and appending to a Weather object:
function Base.push!(w::Weather, x)
    push!(getfield(w, :data), x)
end

function Base.append!(w::Weather, x)
    append!(getfield(w, :data), x)
end


"""
    DataFrame(data::Weather)

Transform a Weather type into a DataFrame.

See also [`Weather`](@ref) to make the reverse.
"""
function DataFrames.DataFrame(data::Weather)
    return DataFrames.DataFrame(data.data)
end
