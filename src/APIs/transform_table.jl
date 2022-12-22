"""
    transform(data, args...; operation="transform")

Transforms a `Tables.jl`-alike table using the arguments `args`.
Returns a `Vector` of `NamedTuples`.

# Arguments
- `data`: a `Tables.jl`-alike table
- `args...`: a list of arguments to transform the table. There's 3 forms:
    1. `:var => :new_var` which renames the variable `var` to `new_var`
    2. `:var => (x -> x .+ 1) => :new_var` which computes a new variable `:new_var` by applying the function `(x -> x .+ 1)` to `:var`
    3. `:var` which keeps the variable `var` as is (no renaming or computation)
- `operation="transform"`: the operation to perform. Can be `"transform"` or `"select"`. In `"transform"` mode, 
    the function returns a new table with the same variables as the input table and the optionaly new variables. 
    In `"select"` mode, the function returns a new table with only the variables required by the user.

# Examples

```julia
using Dates, PlantMeteo
file = joinpath(dirname(dirname(pathof(PlantMeteo))),"test","data","meteo.csv")
data, metadata = PlantMeteo.read_weather_(file)
date_format = Dates.DateFormat("yyyy/mm/dd")

meteo = PlantMeteo.transform(
    data,
    :temperature => :T,
    :relativeHumidity => (x -> x ./100) => :Rh,
    :wind => :Wind,
    :atmosphereCO2_ppm => :Cₐ,
    (x -> PlantMeteo.compute_date(x, date_format)) => :date,
    (x -> PlantMeteo.compute_duration(x)) => :duration,
)
```
"""
function transform(data, args...; operation="transform")
    @assert operation in ("transform", "select") "operation must be either \"transform\" or \"select\""
    args = (args...,)

    if length(args) == 0
        return NamedTuple.(data)
    end

    row_dict = preallocated_row(data, args; operation=operation)
    rows = [transform_row(row, row_dict, args) for row in data]

    return rows
end

"""
    preallocated_row(data, args; operation="transform")

Pre-allocates a `Dict` to be used in [`transform_row`](@ref) to avoid 
allocating a new `Dict` for each row. The variables in the `Dict`
depends on the `operation` argument and the `args` argument.
"""
function preallocated_row(data, args; operation="transform")
    nt = NamedTuple(data[1])
    # pre-allocate the dict with the new variables
    if operation == "select"
        # in "select" mode, we want to keep only the variables required by the user
        row = Dict{Symbol,Any}()
    else
        # in "transform" mode, we want to keep all the variables
        row = Dict{Symbol,Any}(zip(keys(nt), values(nt)))
    end

    # pre-allocate the dict with the new variables
    for a in args
        isa(a, Symbol) && continue # case 3
        !isa(a, Pair) && error("Invalid argument: $a, please check its definition.")
        if isa(a.first, Base.Callable)
            # Here we have the form (x -> x.var .+ 1) => :new_var
            push!(row, a.second => a.first(nt))
        elseif isa(a.second, Pair)
            push!(row, a.second.second => a.second.first(nt[a.first]))
            # remove the old variable if we are not in "select" mode:
            operation == "select" && pop!(row, a.first)
        else
            push!(row, a.second => nt[a.first])
            pop!(row, a.first) # remove the old variable as it was renamed
        end
    end

    return row
end


"""
    transform_row(row, dict_row, args)

Transforms a row of a `Tables.jl`-alike table using the arguments `args`.
The function efficiently transforms a pre-allocated `dict_row` in-place.

# Arguments
- `row::NamedTuple`: a `Tables.jl` row.
- `dict_row::Dict`: a pre-allocated `Dict` with the output variables (see [`preallocated_row`](@ref)).
- `args::Tuple`: the transormations as given in `DataFrames.jl`.

# Details

The `args` argument is a tuple of `Pair`s or `Symbol`s. The `Pair` form is
`(:var => :new_var)` or `(:var => (x -> x .+ 1) => :new_var)`. The first form
renames the variable `:var` to `:new_var`. The second form renames the variable
`:var` to `:new_var` and applies the function `(x -> x .+ 1)` to it. The `Symbol`
form is `:var` which selects the variable `:var` and keeps the same name.

`dict_row` is a pre-allocated `Dict` with the output variables. The function
transforms `dict_row` in-place, so it should 
be pre-allocated with the output variables already.
"""
function transform_row(row, dict_row, args, operation="transform")
    nt_row = NamedTuple(row)

    if operation == "transform"
        # If we are in "transform" mode, we want to keep all the variables, so we copy their values into the dict first:
        for (k, v) in pairs(nt_row)
            dict_row[k] = v
        end
    end

    for a in args
        # If the user only passed a symbol, we don't do anything (it selects the variable)
        if isa(a, Symbol)
            dict_row[a] = nt_row[a]
            continue
        end

        # Else, it must be a Pair
        !isa(a, Pair) && error("The arguments should be a tuple of Pairs or Symbols. Got $a instead.")

        !isa(a, Pair) && error("Invalid argument: $a, please check its definition.")

        if isa(a.first, Base.Callable)
            # Here we have the form (x -> x.var .+ 1) => :new_var
            push!(dict_row, a.second => a.first(nt_row))
        elseif isa(a.second, Pair)
            # Here we have the form :var => (x -> x .+ 1) => :new_var, we transform "var" with the function 
            # and put the result in "new_var"
            dict_row[a.second.second] = a.second.first(nt_row[a.first])
        else
            # Here we have the form :var => :new_var, we rename the variable
            dict_row[a.second] = nt_row[a.first]
        end
    end

    return NamedTuple(dict_row)
end