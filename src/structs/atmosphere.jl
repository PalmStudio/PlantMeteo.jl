"""
Abstract atmospheric conditions type. The suptypes of AbstractAtmosphere should describe the
atmospheric conditions for one time-step only, see *e.g.* [`Atmosphere`](@ref)
"""
abstract type AbstractAtmosphere end


"""
Atmosphere structure to hold all values related to the meteorology / atmosphere.

# Arguments

- `date<:AbstractDateTime = Dates.now()`: the date of the record.
- `duration<:Period = Dates.Second(1.0)`: the duration of the time-step in Dates.Period.
- `T` (°C): air temperature
- `Wind` (m s-1): wind speed
- `Rh` (0-1): relative humidity (can be computed using `rh_from_vpd`)
- `P = DEFAULTS.P` (kPa): air pressure. The default value is at 1 atm, *i.e.* the mean sea-level
atmospheric pressure on Earth.
- `Precipitations = DEFAULTS.Precipitations` (mm): precipitations from atmosphere (*i.e.* rain, snow, hail, etc.)
- `Cₐ = DEFAULTS.Cₐ` (ppm): air CO₂ concentration
- `check = true`: whether to check the validity of the input values.
- `e = vapor_pressure(T,Rh)` (kPa): vapor pressure
- `eₛ = e_sat(T)` (kPa): saturated vapor pressure
- `VPD = eₛ - e` (kPa): vapor pressure deficit
- `ρ = air_density(T, P, constants.Rd, constants.K₀)` (kg m-3): air density
- `λ = latent_heat_vaporization(T, constants.λ₀)` (J kg-1): latent heat of vaporization
- `γ = psychrometer_constant(P, λ, constants.Cₚ, constants.ε)` (kPa K−1): psychrometer "constant"
- `ε = atmosphere_emissivity(T,e,constants.K₀)` (0-1): atmosphere emissivity
- `Δ = e_sat_slope(meteo.T)` (0-1): slope of the saturation vapor pressure at air temperature
- `clearness::A = Inf` (0-1): Sky clearness
- `Ri_SW_f::A = Inf` (W m-2): Incoming short wave radiation flux
- `Ri_PAR_f::A = Inf` (W m-2): Incoming PAR flux
- `Ri_NIR_f::A = Inf` (W m-2): Incoming NIR flux
- `Ri_TIR_f::A = Inf` (W m-2): Incoming TIR flux
- `Ri_custom_f::A = Inf` (W m-2): Incoming radiation flux for a custom waveband

# Notes

The structure can be built using only `T`, `Rh`, `Wind` and `P`. All other variables are optional
and either let at their default value or automatically computed using the functions given in `Arguments`.

# Examples

```julia
Atmosphere(T = 20.0, Wind = 1.0, P = 101.3, Rh = 0.65)
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
