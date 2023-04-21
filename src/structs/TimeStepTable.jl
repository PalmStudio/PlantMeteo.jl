"""
    TimeStepTable(vars)
    
`TimeStepTable` stores variables values for each time step, *e.g.* weather variables.
It implements the `Tables.jl` interface, so it can be used with any package that uses 
`Tables.jl` (like `DataFrames.jl`).

You can extend `TimeStepTable` to store your own variables by defining a new type for the 
storage of the variables. You can look at the [`Atmosphere`](@ref) type 
for an example implementation, or the `Status` type from 
[`PlantSimEngine.jl`](https://github.com/VEZY/PlantSimEngine.jl).

# Examples

```julia
data = TimeStepTable(
    [
        Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65),
        Atmosphere(T = 23.0, Wind = 1.5, P = 101.3, Rh = 0.60),
        Atmosphere(T = 25.0, Wind = 3.0, P = 101.3, Rh = 0.55)
    ]
)

# We can convert it into a DataFrame:
using DataFrames
df = DataFrame(data)

# We can also create a TimeStepTable from a DataFrame:
TimeStepTable(df)

# Note that by default it will use NamedTuple to store the variables
# for high performance. If you want to use a different type, you can
# specify it as a type parameter (if you want *e.g.* mutability or pre-computations):
TimeStepTable{Atmosphere}(df)
# Or if you use PlantSimEngine: TimeStepTable{Status}(df)
```
"""
struct TimeStepTable{T}
    names::NTuple{N,Symbol} where {N}
    metadata::NamedTuple
    ts::Vector{T}
end

TimeStepTable(ts::V, metadata=NamedTuple()) where {V<:Vector} = TimeStepTable(keys(ts[1]), metadata, ts)

# If the metadata is a Dict, we convert it to a NamedTuple
function TimeStepTable(ts::V, metadata::D) where {V<:Vector,D<:Dict}
    md = NamedTuple(zip(Symbol.(keys(metadata)), values(metadata)))
    TimeStepTable(ts, md)
end

function TimeStepTable{T}(ts, metadata=NamedTuple()) where {T}
    TimeStepTable([T(; i...) for i in Tables.namedtupleiterator(ts)], metadata)
end

function TimeStepTable(ts, metadata=NamedTuple())
    TimeStepTable([i for i in Tables.namedtupleiterator(ts)], metadata)
end

Tables.materializer(t::TimeStepTable{T}) where {T} = TimeStepTable{T}

# DataAPI interface:
DataAPI.metadatasupport(::Type{<:TimeStepTable}) = (read=true, write=false)
metadatakeys(t::T) where {T<:TimeStepTable} = string.(keys(getfield(t, :metadata)))

function metadata(t::T, key::Union{AbstractString,Symbol}, default=NamedTuple(); style::Bool=false) where {T<:TimeStepTable}
    meta = getfield(t, :metadata)
    key = Symbol(key) # Convert to Symbol, we need it as an AbstractString for compatibility with DataAPI but we use Symbols internally
    if !hasproperty(meta, key)
        if default === NamedTuple()
            throw(ArgumentError("\"$key\" not found in table metadata"))
        else
            return style ? (default, :note) : default
        end
    end
    return style ? (meta[key], :note) : meta[key]
end


# TimeStepRow definition (efficient view-like access to a row in a TimeStepTable):
struct TimeStepRow{T} <: Tables.AbstractRow
    row::Int
    source::TimeStepTable{T}
end

Base.parent(ts::TimeStepRow) = getfield(ts, :source)
rownumber(ts::TimeStepRow) = getfield(ts, :row)

# Defining the generic implementation of row_from_parent:
row_from_parent(row, i) = Tables.rows(parent(row))[i]

# And the more optimized version for TimeStepRow:
row_from_parent(row::TimeStepRow, i) = parent(row)[i]

"""
    next_row(row::TimeStepRow, i=1)

Return the next row in the table.
"""
next_row(row, i=1) = row_from_parent(row, rownumber(row) + i)

"""
    prev_row(row::TimeStepRow, i=1)

Return the previous row in the table.
"""
prev_row(row, i=1) = row_from_parent(row, rownumber(row) - i)


###### Tables.jl interface ######

Tables.istable(::Type{TimeStepTable{T}}) where {T} = true

# Keys should be the same between TimeStepTable so we only need the ones from the first timestep
Base.keys(ts::TimeStepTable) = getfield(ts, :names)
names(ts::TimeStepTable) = keys(ts)
# matrix(ts::TimeStepTable) = reduce(hcat, [[i...] for i in ts])'

function Tables.schema(m::TimeStepTable)
    Tables.Schema(names(m), DataType[i.types[1] for i in T.parameters[2]])
end

Tables.materializer(::Type{TimeStepTable}) = TimeStepTable

Tables.rowaccess(::Type{<:TimeStepTable}) = true

function Tables.rows(t::TimeStepTable)
    return [TimeStepRow(i, t) for i in 1:length(t)]
end

Base.eltype(::Type{TimeStepTable{T}}) where {T} = TimeStepRow{T}

function Base.length(A::TimeStepTable{T}) where {T}
    length(getfield(A, :ts))
end

nrow(ts::T) where {T<:TimeStepTable} = length(ts) # uses DataAPI.jl interface
ncol(ts::T) where {T<:TimeStepTable} = length(getfield(ts, :names))  # uses DataAPI.jl interface

Tables.columnnames(ts::TimeStepTable) = getfield(ts, :names)

# Iterate over all time-steps in a TimeStepTable object.
# Base.iterate(st::TimeStepTable{T}, i=1) where {T} = i > length(st) ? nothing : (getfield(st, :ts)[i], i + 1)
Base.iterate(t::TimeStepTable{T}, st=1) where {T} = st > length(t) ? nothing : (TimeStepRow(st, t), st + 1)
Base.size(t::TimeStepTable{T}, dim=1) where {T} = dim == 1 ? nrow(t) : ncol(t)

"""
    row_struct(ts::TimeStepRow)

Get `TimeStepRow` in its raw format, *e.g.* the `NamedTuple` that stores the values, 
or the `Atmosphere` of values (or `Status` for `PlantSimEngine.jl`).
"""
function row_struct(row::TimeStepRow)
    getfield(parent(row), :ts)[rownumber(row)]
end

"""
    Tables.getcolumn(row::TimeStepRow, nm::Symbol)
    Tables.getcolumn(row::TimeStepRow, nm::Int)

Get the value of a variable in a `TimeStepRow` object.
"""
Tables.getcolumn(row::TimeStepRow, i) = row_struct(row)[i]

# Defining the following two to avoid ambiguity warnings from Tables.jl:
Tables.getcolumn(row::TimeStepRow, nm::Symbol) = row_struct(row)[nm]
Tables.getcolumn(row::TimeStepRow, i::Int) = row_struct(row)[i]

Tables.columnnames(row::TimeStepRow) = getfield(parent(row), :names)

"""
    setindex!(row::TimeStepRow, nm::Symbol)
    setindex!(row::TimeStepRow, i::Int)

Set the value of a variable in a `TimeStepRow` object.
"""
function Base.setindex!(row::TimeStepRow, x, i)
    setproperty!(row_struct(row), i, x)
end

function Base.setproperty!(row::TimeStepRow, nm::Symbol, x)
    setproperty!(row_struct(row), nm, x)
end

##### Indexing and setting:

# Indexing a TimeStepTable object with the dot syntax returns values of all time-steps for a
# variable (e.g. `status.A`).
function Base.getproperty(ts::TimeStepTable, key::Symbol)
    getproperty(Tables.columns(ts), key)
end

function Base.propertynames(ts::TimeStepTable)
    keys(Tables.columns(ts))
end

Base.names(ts::TimeStepTable) = propertynames(ts)

# Indexing with a Symbol extracts the variable (same as getproperty):
function Base.getindex(ts::TimeStepTable, index::Symbol)
    getproperty(ts, index)
end

function Base.getindex(ts::TimeStepTable, index)
    getproperty(ts, Symbol(index))
end

# Setting the values of a variable in a TimeStepTable object is done by indexing the object
# and then providing the values for the variable (must match the length).
function Base.setproperty!(ts::TimeStepTable, s::Symbol, x)
    @assert length(x) == length(ts)
    for (i, row) in enumerate(Tables.rows(ts))
        setproperty!(row, s, x[i])
    end
end

@inline function Base.getindex(ts::TimeStepTable, row_ind::Integer, col_ind::Integer)
    rows = Tables.rows(ts)
    @boundscheck begin
        if col_ind < 1 || col_ind > length(keys(ts))
            throw(BoundsError(ts, (row_ind, col_ind)))
        end
        if row_ind < 1 || row_ind > length(ts)
            throw(BoundsError(ts, (row_ind, col_ind)))
        end
    end
    return @inbounds rows[row_ind][col_ind]
end

# Indexing a TimeStepTable in one dimension only gives the row (e.g. `ts[1] == ts[1,:]`)
@inline function Base.getindex(ts::TimeStepTable, i::Integer)
    rows = Tables.rows(ts)
    @boundscheck begin
        if i < 1 || i > length(ts)
            throw(BoundsError(ts, i))
        end
    end

    return @inbounds rows[i]
end

"""

Get row from `TimeStepTable` in its raw format, *e.g.* as a `NamedTuple`
or `Atmosphere` of values.
"""
function get_index_raw(ts::TimeStepTable, i::Integer)
    row_struct(ts[i])
end

Base.lastindex(ts::TimeStepTable) = length(ts)
Base.lastindex(ts::TimeStepTable, dim::Integer) = size(ts, dim)
Base.firstindex(ts::TimeStepTable) = 1
Base.firstindex(ts::TimeStepTable, dim::Integer) = 1
Base.axes(ts::TimeStepTable) = (firstindex(ts):lastindex(ts), firstindex(ts, 2):lastindex(ts, 2))

# Indexing a TimeStepTable with a colon (e.g. `ts[1,:]`) gives all values in column.
@inline function Base.getindex(ts::TimeStepTable, row_ind::Integer, ::Colon)
    return getindex(ts, row_ind)
end

# Indexing a TimeStepTable with a colon (e.g. `ts[:,1]`) gives all values in the row.
@inline function Base.getindex(ts::TimeStepTable, ::Colon, col_ind::Integer)
    return getproperty(Tables.columns(ts), col_ind)
end

# Pushing and appending to a TimeStepTable object:
function Base.push!(ts::TimeStepTable, x)
    push!(getfield(ts, :ts), x)
end

function Base.append!(ts::TimeStepTable, x)
    append!(getfield(ts, :ts), x)
end

function Base.show(io::IO, t::TimeStepTable{T}) where {T}
    length(t) == 0 && return

    T_string = string(T)
    if length(T_string) > 30
        T_string = string(T_string[1:prevind(T_string, 30)], "...")
    end

    print(
        io,
        "TimeStepTable{$(T_string)}($(length(t)) x $(length(getfield(t,:names)))):\n"
    )

    #! Note: There should be a better way to add the TimeStep as the first column. 
    # Here we transform the whole table into a matrix and pass the header manually... 
    # Also we manually replace last columns or rows by ellipsis if the table is too long or too wide.

    t_mat = Tables.matrix(t)
    col_names = [:Step, getfield(t, :names)...]
    ts_column = string.(1:size(t_mat, 1)) # TimeStep index column

    if get(io, :compact, false) || get(io, :limit, true)
        # We need the values in the matrix to be Strings to perform the truncation (and it is done afterwards too so...)
        typeof(t_mat) <: Matrix{String} || (t_mat = string.(t_mat))

        disp_size = displaysize(io)
        if size(t_mat, 1) * Term.Measures.height(t_mat[1, 1]) >= disp_size[1]
            t_mat = vcat(t_mat[1:disp_size[1], :], fill("...", (1, size(t_mat, 2))))
            # We need to add the TimeStep as the first column:
            ts_column = ts_column[1:disp_size[1]+1]
            ts_column[end] = "..."
        end

        # Header size (usually the widest):
        space_around_text = 8
        header_size = textwidth(join(col_names, join(fill(" ", space_around_text))))
        # Maximum column size:
        colsize = findmax(first, textwidth(join(t_mat[i, :], join(fill(" ", space_around_text)))) for i in axes(t_mat, 1))

        # Find the column that goes beyond the display:
        if header_size >= colsize[1]
            # The header is wider
            max_col_index = findfirst(x -> x > disp_size[2], cumsum(textwidth.(string.(col_names)) .+ space_around_text))
        else
            # One of the columns is wider
            max_col_index = findfirst(x -> x > disp_size[2], cumsum(textwidth.(t_mat[colsize[2], :]) .+ space_around_text))
        end

        if max_col_index !== nothing
            # We found a column that goes beyond the display, so we need to truncate starting from this one (also counting the extra ...)
            t_mat = t_mat[:, 1:max_col_index-2]
            # And we add an ellipsis to the last column for clarity:
            t_mat = hcat(t_mat, repeat(["..."], size(t_mat, 1)))
            # Add the ellipsis to the column names:
            col_names = [col_names[1:max_col_index-1]..., Symbol("...")]
            # remember that the first column is the TimeStep so we don't use max_col_index-2 here
        end
    end

    t_mat = Tables.table(hcat(ts_column, t_mat), header=col_names)

    st_panel = Term.Tables.Table(
        t_mat;
        box=:ROUNDED, style="red", compact=false
    )
    print(io, st_panel)

    if length(metadata(t)) > 0
        print(
            io,
            Term.RenderableText(
                "Metadata: `$(metadata(t))`";
                style="bold"
            )
        )
    end
end


function Base.show(io::IO, row::TimeStepRow)
    limit = get(io, :limit, true)
    i = rownumber(row)
    st = getfield(parent(row), :ts)[i]
    ts_print = "Step $i: " * show_long_format_row(st, limit)

    st_panel = Term.Panel(
        ts_print,
        title="TimeStepRow",
        style="red",
        fit=false,
    )

    print(io, Term.highlight(st_panel))
end
