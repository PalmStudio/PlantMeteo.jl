"""
    to_daily(df, args...)
    to_daily(t::T, args...) where {T<:TimeStepTable{<:Atmosphere}}

Transform a `DataFrame` object or `TimeStepTable{<:Atmosphere}` with
sub-daily time steps (*e.g.* 1h) to a daily time-step table.

# Arguments

- `t`: a `TimeStepTable{<:Atmosphere}` with sub-daily time steps (*e.g.* 1h)
- `args`: a list of transformations to apply to the data, formates as for `DataFrames.jl`

# Notes 

Default transformations are applied to the data, and can be overriden by the user.
The default transformations are:
- `:date => (x -> unique(Dates.Date.(x))) => :date`: the date is transformed into a `Date` object
- `:duration => sum => :duration`: the duration is summed
- `:T => minimum => :Tmin`: we use the minimum temperature for Tmin
- `:T => maximum => :Tmax`: and the maximum temperature for Tmax
- `:Precipitations => sum => :Precipitations`: the precipitations are summed
- `:Rh => mean => :Rh`: the relative humidity is averaged
- `:Wind, :P, :Rh, :Cₐ, :e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness` are 
all averaged
- `:Ri_SW_f => mean => :Ri_SW_f`: the irradiance is averaged (W m-2)
- `[:Ri_SW_f, :duration] => ((x, y) -> sum(x .* Dates.toms.(y)) * 1.0e-9) => :Ri_SW_q`: the irradiance is also summed (MJ m-2 d-1)
- All other irradiance variables are also averaged or integrated (see the code for details)

Note that the default transformations can be overriden by the user, and that the
default transformations are only applied if the variable is available.


# Examples

```julia
using PlantMeteo, Dates
# Forecast for today and tomorrow:
period = [today(), today()+Dates.Day(1)]
w = get_weather(48.8566, 2.3522, period)
# Convert to daily:
w_daily = to_daily(w, :T => mean => :Tmean)
```
"""
function to_daily(df::DataFrames.DataFrame, args...)

    @assert hasproperty(df, :date) "The TimeStepTable must have a `date` column."

    if !hasproperty(df, :year)
        df.year = Dates.year.(df.date)
    end

    if !hasproperty(df, :dayofyear)
        df.dayofyear = Dates.dayofyear.(df.date)
    end

    # Check that the durations in a day sum up to 24h (86400ms):
    check_day_complete(df)

    def_trans = default_transformation(df)
    def_trans_names = new_names(def_trans)
    user_trans_names = new_names(args)

    # remove the default transformations that are overriden by the user:
    deleteat!(
        def_trans,
        findall(x -> x in user_trans_names, def_trans_names)
    )

    df = DataFrames.combine(
        DataFrames.groupby(df, [:year, :dayofyear]),
        def_trans...,
        args...
    )

    return df
end

function to_daily(t::T, args...) where {T<:TimeStepTable{<:Atmosphere}}
    df = to_daily(DataFrames.DataFrame(t), args...)
    return TimeStepTable{Atmosphere}(df, metadata(t))
end

"""
    new_names(args)

Get the new names of the columns after the transformation provided 
by the user.
"""
function new_names(args)
    new_names = Symbol[]
    for i in args
        if isa(i, Pair)
            if i.second isa Function
                push!(new_names, Symbol(string(i.first, "_", i.second)))
            elseif isa(i.second, Pair)
                push!(new_names, i.second.second)
            elseif isa(i.second, Symbol)
                push!(new_names, i.second)
            else
                error("The transformation must be a function or a symbol.")
            end
        else
            error("You should apply a transformation to the column to get a daily value.")
        end
    end

    return new_names
end

"""
    default_transformation(df)

Return the default transformations to apply to the `df` `DataFrame` 
for the `to_daily` function. If the variable is not available, the transformation is not applied.

The default transformations are:

- `:date => (x -> unique(Dates.Date.(x))) => :date`: the date is transformed into a `Date` object
- `:duration => sum => :duration`: the duration is summed
- `:T => minimum => :Tmin`: we use the minimum temperature for Tmin
- `:T => maximum => :Tmax`: and the maximum temperature for Tmax
- `:T => mean => :T`: and the average daily temperature (!= than average of Tmin and Tmax)
- `:Precipitations => sum => :Precipitations`: the precipitations are summed
- `:Rh => mean => :Rh`: the relative humidity is averaged
- `:Wind, :P, :Rh, :Cₐ, :e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness` are 
all averaged
- `:Ri_SW_f => mean => :Ri_SW_f`: the irradiance is averaged (W m-2)
- `[:Ri_SW_f, :duration] => ((x, y) -> sum(x .* Dates.toms.(y)) * 1.0e-9) => :Ri_SW_q`: the irradiance is also summed (MJ m-2 d-1)
- All other irradiance variables are also averaged or integrated (see the code for details)

"""
function default_transformation(df)
    trans = Pair[]

    # The date is only a Date now (and not a DateTime):
    add_transformations!(df, trans, (:date,), (x -> unique(Dates.Date.(x))); error_missing=false)
    add_transformations!(df, trans, (:duration,), (x -> Dates.Day.(sum(x))); error_missing=false)

    # Compute Tmin, Tmax, and cumulate time-steps durations and Precipitations:
    add_transformations!(df, trans, (:T => :Tmin,), minimum; error_missing=false)
    add_transformations!(df, trans, (:T => :Tmax,), maximum; error_missing=false)
    add_transformations!(df, trans, (:T,), Statistics.mean; error_missing=false)
    add_transformations!(df, trans, (:Precipitations,), sum; error_missing=false)

    # Compute the average of the following variables:
    to_average = (
        :Wind, :P, :Rh, :Cₐ, :e, :eₛ, :VPD, :ρ, :λ, :γ, :ε, :Δ, :clearness,
        :Ri_SW_f, :Ri_PAR_f, :Ri_NIR_f, :Ri_TIR_f, :Ri_custom_f
    )
    # Note: e.g. Ri_SW_f is the average radiation in W/m²

    add_transformations!(df, trans, to_average, Statistics.mean; error_missing=false)

    # NOte: e.g. Ri_SW_q is the radiation in MJ/m²/day:
    to_transform = (
        [:Ri_SW_f, :duration] => :Ri_SW_q,
        [:Ri_PAR_f, :duration] => :Ri_PAR_q,
        [:Ri_NIR_f, :duration] => :Ri_NIR_q,
        [:Ri_TIR_f, :duration] => :Ri_TIR_q,
        [:Ri_custom_f, :duration] => :Ri_custom_q,
    )

    add_transformations!(
        df,
        trans,
        to_transform,
        ((x, y) -> sum(x .* Dates.toms.(y)) * 1.0e-9);
        error_missing=false
    )

    return trans
end

"""
    add_transformations!(df, trans, vars, fun; error_missing=false)

Add the `fun` transformations to the `trans` vector for the 
variables `vars` found in the `df` DataFrame.

# Arguments

- `df`: the DataFrame
- `trans`: the vector of transformations (will be modified in-place)
- `vars`: the variables to transform (can be a symbol, a vector of symbols or a pairs :var => :new_var)
- `fun`: the function to apply to the variables
- `error_missing=true`: if `true`, the function returns an error if the variable is not found. If `false`, 
the variable is not added to `trans`.
"""
function add_transformations!(df, trans, vars, fun; error_missing=true)
    for var in vars
        if isa(var, Pair)
            if isa(var.second, Symbol)
                new_var = var.second
            elseif isa(var.second, Pair)
                new_var = var.second.second
            else
                error("The transformation must be a function or a symbol.")
            end
            var = var.first
        else
            new_var = var
        end

        isa(var, Symbol) && (var = [var,])

        add_var = true
        for i in var
            if !hasproperty(df, i)
                if error_missing
                    # If the variable is not in the DataFrame, return an error:
                    error("The variable $i is not in the DataFrame.")
                else
                    # If the variable is not in the DataFrame, we don't add the transformation:
                    add_var = false
                end
            end
        end

        add_var && push!(trans, var => fun => new_var)
    end
end