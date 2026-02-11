"""
Internal helpers for table manipulation without depending on DataFrames.
"""

# Materialize any Tables.jl source as a column table (NamedTuple of columns).
table_columns(data) = Tables.columntable(data)

# Metadata is currently only guaranteed on TimeStepTable in this package.
table_metadata(::Any) = NamedTuple()
table_metadata(t::TimeStepTable) = getfield(t, :metadata)

function set_column(data, name::Symbol, values)
    cols = table_columns(data)
    names = collect(Symbol.(propertynames(cols)))
    vectors = Any[Tables.getcolumn(cols, n) for n in names]
    idx = findfirst(==(name), names)

    if isnothing(idx)
        push!(names, name)
        push!(vectors, values)
    else
        vectors[idx] = values
    end

    return NamedTuple{Tuple(names)}(Tuple(vectors))
end

function rename_columns(data, renamer::Function)
    cols = table_columns(data)
    names = collect(Symbol.(propertynames(cols)))
    vectors = Any[Tables.getcolumn(cols, n) for n in names]
    new_names = Symbol[renamer(n) for n in names]

    return NamedTuple{Tuple(new_names)}(Tuple(vectors))
end

function transform_columns(data, args...)
    cols = table_columns(data)
    names = collect(Symbol.(propertynames(cols)))
    vectors = Any[Tables.getcolumn(cols, n) for n in names]
    nrows = isempty(vectors) ? 0 : length(vectors[1])

    for arg in args
        if arg isa Symbol
            hasproperty(cols, arg) || error("The variable $arg is not in the table.")
            continue
        end

        arg isa Pair || error("Invalid transformation argument `$arg`.")
        src = arg.first
        src isa Symbol || error("Only Symbol source columns are supported, got `$src`.")
        hasproperty(cols, src) || error("The variable $src is not in the table.")

        rhs = arg.second
        if rhs isa Pair
            fun = rhs.first
            new_name = rhs.second
            fun isa Function || error("The transformation for `$src` must be a function.")
            new_col = fun(Tables.getcolumn(cols, src))
        elseif rhs isa Symbol
            new_name = rhs
            new_col = Tables.getcolumn(cols, src)
        else
            error("Invalid transformation format `$arg`.")
        end

        if !(new_col isa AbstractVector)
            new_col = fill(new_col, nrows)
        elseif length(new_col) != nrows
            error("Transformation for `$src` returned a column of invalid length.")
        end

        idx = findfirst(==(new_name), names)
        if isnothing(idx)
            push!(names, new_name)
            push!(vectors, new_col)
        else
            vectors[idx] = new_col
        end
    end

    return NamedTuple{Tuple(names)}(Tuple(vectors))
end
