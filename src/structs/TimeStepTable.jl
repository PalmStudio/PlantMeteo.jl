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

# Indexing examples:
data[:T]      # full column by Symbol
data["T"]     # full column by String
data[1]       # one row
data[1:2]     # row subset as TimeStepTable
data[1, :]    # one row (matrix-like syntax)
data[1, :T]   # one cell by row + Symbol column
data[1, "T"]  # one cell by row + String column
data[1:2, :T] # vector slice from one column
data[1:2, "T"]
```
"""
struct TimeStepTable{T}
    names::NTuple{N,Symbol} where {N}
    metadata::NamedTuple
    ts::Vector{T}
end

TimeStepTable(ts::V, metadata=NamedTuple()) where {V<:Vector} = TimeStepTable(keys(ts[1]), metadata, ts)
TimeStepTable(ts::V, metadata=NamedTuple()) where {V<:Vector{<:AbstractDict}} = TimeStepTable((keys(ts[1])...,), metadata, ts)

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

# Shortcut for when the input is already a TimeStepTable:
function TimeStepTable(ts::TS) where {TS<:TimeStepTable}
    return ts
end

# Another shortcut for when the input is already a TimeStepTable with the same type parameter:
function TimeStepTable{T}(ts::TimeStepTable{T}) where {T}
    return ts
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

struct TimeStepRows{S<:TimeStepTable}
    source::S
end

struct TimeStepColumn{S<:TimeStepTable} <: AbstractVector{Any}
    source::S
    col_ind::Int
end

Base.parent(ts::TimeStepRow) = getfield(ts, :source)
rownumber(ts::TimeStepRow) = getfield(ts, :row)
Base.parent(ts::TimeStepRows) = getfield(ts, :source)

Base.length(rows::TimeStepRows) = length(parent(rows))
Base.IteratorSize(::Type{<:TimeStepRows}) = Base.HasLength()

@inline function Base.getindex(rows::TimeStepRows, i::Int)
    @boundscheck if i < 1 || i > length(rows)
        throw(BoundsError(parent(rows), i))
    end
    return TimeStepRow(i, parent(rows))
end

Base.iterate(rows::TimeStepRows, st=1) =
    st > length(rows) ? nothing : (TimeStepRow(st, parent(rows)), st + 1)

Base.length(col::TimeStepColumn) = length(getfield(col, :source))
Base.size(col::TimeStepColumn) = (length(col),)
Base.axes(col::TimeStepColumn) = (Base.OneTo(length(col)),)
Base.IndexStyle(::Type{<:TimeStepColumn}) = IndexLinear()

@inline _row_get_value(row::AbstractDict, ::Int, col_name::Symbol) = row[col_name]
@inline _row_get_value(row, col_ind::Int, ::Symbol) = row[col_ind]

@inline function Base.getindex(col::TimeStepColumn, i::Int)
    ts = getfield(col, :source)
    col_ind = getfield(col, :col_ind)
    @boundscheck if i < 1 || i > length(ts)
        throw(BoundsError(col, i))
    end

    row = @inbounds getfield(ts, :ts)[i]
    col_name = @inbounds getfield(ts, :names)[col_ind]
    return @inbounds _row_get_value(row, col_ind, col_name)
end

# Defining the generic implementation of row_from_parent:
row_from_parent(row, i) = Tables.rows(parent(row))[i]

# And the more optimized version for TimeStepRow:
row_from_parent(row::TimeStepRow, i) = parent(row)[i]

function Base.getindex(row::TimeStepRow{T}, i::Int) where {T<:AbstractDict}
    ts = parent(row)
    raw_row = getfield(ts, :ts)[rownumber(row)]
    getindex(raw_row, getfield(ts, :names)[i])
end

"""
    next_row(row::TimeStepRow, i=1)

Return the next row in the table.
"""
@inline function next_row(row, i=1)
    @boundscheck if rownumber(row) + i > lastindex(parent(row))
        throw(BoundsError(parent(row), rownumber(row) + i))
    end
    return row_from_parent(row, rownumber(row) + i)
end

"""
    next_value(row::TimeStepRow, var, next_index=1; default=nothing)

Return the value of `var` in the next row in the table, or `default` if there is no next row.
"""
@inline function next_value(row, var, next_index=1; default=nothing)
    @boundscheck if rownumber(row) + next_index > lastindex(parent(row))
        return default
    end
    return @inbounds next_row(row, next_index)[var]
end

"""
    prev_row(row::TimeStepRow, i=1)

Return the previous row in the table, or `default` if there is no previous row.
"""
@inline function prev_row(row, i=1)
    @boundscheck if rownumber(row) - i < firstindex(parent(row))
        throw(BoundsError(parent(row), rownumber(row) + i))
    end
    return row_from_parent(row, rownumber(row) - i)
end

"""
    prev_value(row::TimeStepRow, var, prev_index=1; default=nothing)

Return the value of `var` in the previous row in the table, or `default` if there is no previous row.
"""
@inline function prev_value(row, var, prev_index=1; default=nothing)
    @boundscheck if rownumber(row) - prev_index < firstindex(parent(row))
        return default
    end
    return @inbounds prev_row(row, prev_index)[var]
end

###### Tables.jl interface ######

Tables.istable(::Type{TimeStepTable{T}}) where {T} = true

# Keys should be the same between TimeStepTable so we only need the ones from the first timestep
Base.keys(ts::TimeStepTable) = getfield(ts, :names)
names(ts::TimeStepTable) = keys(ts)
# matrix(ts::TimeStepTable) = reduce(hcat, [[i...] for i in ts])'

function Tables.schema(m::TimeStepTable)
    Tables.Schema([names(m)...], [typeof(i) for i in _get_field_values(PlantMeteo.row_struct(m[1]))])
end

Tables.materializer(::Type{TimeStepTable}) = TimeStepTable

Tables.rowaccess(::Type{<:TimeStepTable}) = true

function Tables.rows(t::TimeStepTable)
    return TimeStepRows(t)
end

@inline function Tables.getcolumn(ts::TimeStepTable, col_ind::Int)
    @boundscheck if col_ind < 1 || col_ind > length(getfield(ts, :names))
        throw(BoundsError(ts, (:, col_ind)))
    end
    return TimeStepColumn(ts, col_ind)
end

@inline function Tables.getcolumn(ts::TimeStepTable, col_name::Symbol)
    col_ind = findfirst(==(col_name), getfield(ts, :names))
    isnothing(col_ind) && throw(ArgumentError("Column $col_name does not exist in the table."))
    return TimeStepColumn(ts, col_ind)
end

Base.eltype(::Type{TimeStepTable{T}}) where {T} = TimeStepRow{T}

# Helper function to extract field values from a struct
function _get_field_values(x)
    # Try values() first (works for NamedTuples, Dicts, etc.)
    if applicable(values, x)
        val_iter = values(x)
        # Check if the returned value is actually iterable
        # (for structs, values() might just return the struct itself)
        if val_iter !== x && Base.IteratorSize(val_iter) != Base.SizeUnknown()
            return val_iter
        end
    end
    # Fall back to iterating over fields
    return (getfield(x, fn) for fn in fieldnames(typeof(x)))
end

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
    getfield(ts, :names)
end

Base.names(ts::TimeStepTable) = propertynames(ts)

# Indexing with a Symbol extracts the variable (same as getproperty):
function Base.getindex(ts::TimeStepTable, index::Symbol)
    getproperty(ts, index)
end

function Base.getindex(ts::TimeStepTable, index::AbstractString)
    getproperty(ts, Symbol(index))
end

# Indexing with a vector/range of rows returns a TimeStepTable subset.
@inline function Base.getindex(ts::TimeStepTable, row_inds::AbstractVector{<:Integer})
    rows = getfield(ts, :ts)[row_inds]
    TimeStepTable(getfield(ts, :names), getfield(ts, :metadata), rows)
end

@inline function Base.getindex(ts::TimeStepTable, row_inds::AbstractRange{<:Integer})
    rows = getfield(ts, :ts)[row_inds]
    TimeStepTable(getfield(ts, :names), getfield(ts, :metadata), rows)
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
    @boundscheck begin
        if col_ind < 1 || col_ind > length(keys(ts))
            throw(BoundsError(ts, (row_ind, col_ind)))
        end
        if row_ind < 1 || row_ind > length(ts)
            throw(BoundsError(ts, (row_ind, col_ind)))
        end
    end
    row = @inbounds getfield(ts, :ts)[row_ind]
    col_name = @inbounds getfield(ts, :names)[col_ind]
    return @inbounds _row_get_value(row, col_ind, col_name)
end

@inline function Base.getindex(ts::TimeStepTable, row_ind::Integer, col_ind::Symbol)
    col_i = findfirst(==(col_ind), getfield(ts, :names))
    isnothing(col_i) && throw(ArgumentError("Column $col_ind does not exist in the table."))
    return getindex(ts, row_ind, col_i)
end

@inline function Base.getindex(ts::TimeStepTable, row_ind::Integer, col_ind::AbstractString)
    return getindex(ts, row_ind, Symbol(col_ind))
end

# Indexing a TimeStepTable in one dimension only gives the row (e.g. `ts[1] == ts[1,:]`)
@inline function Base.getindex(ts::TimeStepTable, i::Integer)
    @boundscheck begin
        if i < 1 || i > length(ts)
            throw(BoundsError(ts, i))
        end
    end

    return TimeStepRow(i, ts)
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

# Indexing a TimeStepTable with multiple rows and all columns gives a TimeStepTable subset.
@inline function Base.getindex(ts::TimeStepTable, row_inds::AbstractVector{<:Integer}, ::Colon)
    return getindex(ts, row_inds)
end

@inline function Base.getindex(ts::TimeStepTable, row_inds::AbstractRange{<:Integer}, ::Colon)
    return getindex(ts, row_inds)
end

# Indexing a TimeStepTable with a colon (e.g. `ts[:,1]`) gives all values in the row.
@inline function Base.getindex(ts::TimeStepTable, ::Colon, col_ind::Integer)
    return getproperty(Tables.columns(ts), col_ind)
end

@inline function Base.getindex(ts::TimeStepTable, ::Colon, col_ind::Symbol)
    return getproperty(ts, col_ind)
end

@inline function Base.getindex(ts::TimeStepTable, ::Colon, col_ind::AbstractString)
    return getindex(ts, :, Symbol(col_ind))
end

@inline function Base.getindex(ts::TimeStepTable, row_inds::AbstractVector{<:Integer}, col_ind::Symbol)
    return getindex(ts, :, col_ind)[row_inds]
end

@inline function Base.getindex(ts::TimeStepTable, row_inds::AbstractVector{<:Integer}, col_ind::AbstractString)
    return getindex(ts, row_inds, Symbol(col_ind))
end

@inline function Base.getindex(ts::TimeStepTable, row_inds::AbstractRange{<:Integer}, col_ind::Symbol)
    return getindex(ts, :, col_ind)[row_inds]
end

@inline function Base.getindex(ts::TimeStepTable, row_inds::AbstractRange{<:Integer}, col_ind::AbstractString)
    return getindex(ts, row_inds, Symbol(col_ind))
end

# Pushing and appending to a TimeStepTable object:
function Base.push!(ts::TimeStepTable, x)
    push!(getfield(ts, :ts), x)
end

function Base.append!(ts::TimeStepTable, x)
    append!(getfield(ts, :ts), x)
end


function show_ts(t::TimeStepTable{T}, io, io_type) where {T}
    length(t) == 0 && return

    T_string = string(T)
    if length(T_string) > 30
        T_string = string(T_string[1:prevind(T_string, 30)], "...")
    end

    if io_type == :html
        t_format = PrettyTables.HtmlTableFormat()
        t_style = PrettyTables.HtmlTableStyle()
    elseif io_type == :latex
        t_format = PrettyTables.LatexTableFormat()
        t_style = PrettyTables.LatexTableStyle()
    elseif io_type == :markdown
        t_format = PrettyTables.MarkdownTableFormat()
        t_style = PrettyTables.MarkdownTableStyle()
    else
        t_format = PrettyTables.TextTableFormat(borders=PrettyTables.text_table_borders__unicode_rounded)
        t_style = PrettyTables.TextTableStyle(; table_border=Crayons.crayon"red")
    end

    PrettyTables.pretty_table(
        io, t; backend=io_type,
        title="TimeStepTable{$(T_string)}($(length(t)) x $(length(getfield(t,:names)))):",
        table_format=t_format,
        row_number_column_label="Step",
        row_labels=1:length(t),
        vertical_crop_mode=:middle,
        style=t_style,
    )

    if length(metadata(t)) > 0
        print(io, "Metadata: `$(metadata(t))`")
    end
end


function Base.show(io::IO, ::MIME"text/plain", t::TimeStepTable{T}) where {T}
    show_ts(t, io, :text)
end


function Base.show(io::IO, ::MIME"text/html", t::TimeStepTable{T}) where {T}
    show_ts(t, io, :html)
end

function Base.show(io::IO, ::MIME"text/markdown", t::TimeStepTable{T}) where {T}
    show_ts(t, io, :markdown)
end

function Base.show(io::IO, ::MIME"text/latex", t::TimeStepTable{T}) where {T}
    show_ts(t, io, :latex)
end



function Base.show(io::IO, row::TimeStepRow)
    limit = get(io, :limit, true)
    i = rownumber(row)
    ts_print = "Step $i: " * show_long_format_row(row, limit)

    st_panel = Term.Panel(
        ts_print,
        title="TimeStepRow",
        style="red",
        fit=false,
    )

    print(io, Term.highlight(st_panel))
end


function Base.:(==)(ts1::TimeStepTable{T}, ts2::TimeStepTable{T}) where {T}
    return (getfield(ts1, :names) == getfield(ts2, :names)) &&
           (getfield(ts1, :metadata) == getfield(ts2, :metadata)) && (getfield(ts1, :ts) == getfield(ts2, :ts))
end
