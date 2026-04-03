"""
Abstract atmospheric conditions type. The suptypes of AbstractAtmosphere should describe the
atmospheric conditions for one time-step only, see *e.g.* [`Atmosphere`](@ref)
"""
abstract type AbstractAtmosphere end


"""
    Atmosphere(; kwargs...)

One weather timestep in PlantMeteo.

`Atmosphere` is the row-level object used throughout the package. A weather series is typically a
[`Weather`](@ref) or [`TimeStepTable`](@ref) made of `Atmosphere` rows. At minimum, construct it
with `T`, `Wind`, and `Rh`; other fields are optional or can be derived from those core variables.

# Key fields

- `date`: timestamp of the record. Defaults to `Dates.now()`.
- `duration`: timestep duration. Defaults to `Dates.Second(1.0)`.
- `T`: air temperature in degrees Celsius.
- `Wind`: wind speed in m s-1.
- `Rh`: relative humidity in 0-1 units.
- `P`: air pressure in kPa. Defaults to `DEFAULTS.P`.
- `Precipitations`: precipitation over the timestep in mm.
- `Ri_SW_f`: incoming short-wave radiation flux in W m-2.

Additional atmospheric variables such as `e`, `VPD`, `ρ`, `λ`, `γ`, `ε`, and `Δ` can be supplied
explicitly or left to their default computations.

# Example

```julia
using PlantMeteo, Dates

row = Atmosphere(
    date = DateTime(2025, 7, 1, 12),
    duration = Hour(1),
    T = 24.0,
    Wind = 1.8,
    Rh = 0.58,
    P = 101.3,
    Ri_SW_f = 620.0
)
```
"""
struct Atmosphere{N,T<:Tuple} <: AbstractAtmosphere
    nt::NamedTuple{N,T}
end

function Atmosphere(;
    T=nothing, Wind=nothing, Rh=nothing, kwargs...
)
    missing_required = Symbol[]
    isnothing(T) && push!(missing_required, :T)
    isnothing(Wind) && push!(missing_required, :Wind)
    isnothing(Rh) && push!(missing_required, :Rh)
    if !isempty(missing_required)
        missing_str = join(("`$(name)`" for name in missing_required), ", ")
        throw(ArgumentError("Missing mandatory Atmosphere keyword argument(s): $missing_str. Required keyword arguments are `T`, `Wind`, and `Rh`."))
    end

    return _build_atmosphere(; T=T, Wind=Wind, Rh=Rh, kwargs...)
end

# Builder, this is done after checking the required arguments because default values of the other arguments depend on the required ones:
function _build_atmosphere(;
    T, Wind, Rh, date::D1=Dates.now(), duration=Dates.Second(1.0), P=DEFAULTS.P,
    Precipitations=DEFAULTS.Precipitations, Cₐ=DEFAULTS.Cₐ, check=true,
    e=vapor_pressure(T, Rh, check=check), eₛ=e_sat(T), VPD=eₛ - e, ρ=air_density(T, P, check=check),
    λ=latent_heat_vaporization(T), γ=psychrometer_constant(P, λ, check=check),
    ε=atmosphere_emissivity(T, e), Δ=e_sat_slope(T), clearness=Inf,
    Ri_SW_f=Inf, Ri_PAR_f=Inf, Ri_NIR_f=Inf, Ri_TIR_f=Inf, Ri_custom_f=Inf,
    args...
) where {D1<:Dates.AbstractTime}

    for p in pairs((; T, Wind, P, Rh, date, duration))
        if ismissing(p.second)
            throw(ArgumentError("$(p.first) must be different than missing"))
        end
    end

    # Checking some values:
    if Wind <= 0.0
        @warn "Wind ($Wind) should always be > 0, forcing it to 1e-6" maxlog = 1
        Wind = 1.0e-6
    end

    if Rh <= 0.0
        @warn "Rh ($Rh) should always be > 0, forcing it to 1e-6" maxlog = 1
        Rh = 1.0e-6
    end

    if Rh > 1.0
        if 1.0 < Rh < 100.0
            @warn "Rh ($Rh) should be 0 < Rh < 1, assuming it is given in % and dividing by 100" maxlog = 1
            Rh /= 100.0
        else
            @error "Rh ($Rh) should be 0 < Rh < 1"
        end
    end

    if !ismissing(P) && P <= 85.0 || P >= 110.0 # ~ max and min pressure on Earth
        @warn "P ($P) should be in kPa (i.e. 101.325 kPa at sea level), please consider converting it" maxlog = 1
    end

    if !ismissing(clearness) && clearness != Inf && (clearness <= 0.0 || clearness > 1.0)
        @error "clearness ($clearness) should always be 0 < clearness < 1"
    end

    params_same_type =
        (;
            T=T,
            Wind=Wind,
            P=P,
            Rh=Rh,
            Precipitations=Precipitations,
            Cₐ=Cₐ,
            e=e,
            eₛ=eₛ,
            VPD=VPD,
            ρ=ρ,
            λ=λ,
            γ=γ,
            ε=ε,
            Δ=Δ,
            clearness=clearness,
            Ri_SW_f=Ri_SW_f,
            Ri_PAR_f=Ri_PAR_f,
            Ri_NIR_f=Ri_NIR_f,
            Ri_TIR_f=Ri_TIR_f,
            Ri_custom_f=Ri_custom_f
        )

    Atmosphere(
        (;
        date=date,
        duration=duration,
        # We promote the types that we know should share the same type:
        zip(keys(params_same_type), promote(values(params_same_type)...))...,
        args...)
    )
end

Base.keys(::Atmosphere{names}) where {names} = names
Base.values(atm::Atmosphere) = values(getfield(atm, :nt))
Base.NamedTuple(atm::Atmosphere) = NamedTuple{keys(atm)}(values(atm))
Base.Tuple(atm::Atmosphere) = values(atm)
Base.length(atm::Atmosphere) = length(getfield(atm, :nt))

function Base.show(io::IO, t::Atmosphere)
    length(t) == 0 && return
    print(io, "Atmosphere", NamedTuple(t))
end

Base.propertynames(mnt::Atmosphere) = propertynames(getfield(mnt, :nt))
Base.getproperty(mnt::Atmosphere, s::Symbol) = getproperty(getfield(mnt, :nt), s)

# This is for the Tables.jl interface:
Base.getindex(mnt::Atmosphere, i::Int) = getfield(getfield(mnt, :nt), i)
Base.getindex(mnt::Atmosphere, i::Symbol) = getfield(getfield(mnt, :nt), i)
function Base.indexed_iterate(mnt::Atmosphere, i::Int, state=1)
    Base.indexed_iterate(getfield(mnt, :nt), i, state)
end


function show_long_format_row(t, limit=false)
    length(t) == 0 && return
    nt = NamedTuple(t)
    if limit && length(nt) > 10
        nt = NamedTuple{keys(nt)[1:10]}(values(nt)[1:10])
        join([string(k, "=", v) for (k, v) in pairs(nt)], ", ") * " ..."
    else
        join([string(k, "=", v) for (k, v) in pairs(nt)], ", ")
    end
end
