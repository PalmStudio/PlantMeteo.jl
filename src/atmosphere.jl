"""
Abstract atmospheric conditions type. The suptypes of AbstractAtmosphere should describe the
atmospheric conditions for one time-step only, see *e.g.* [`Atmosphere`](@ref)
"""
abstract type AbstractAtmosphere end


"""
Atmosphere structure to hold all values related to the meteorology / atmosphere.

# Arguments

- `date = Dates.now()`: the date of the record.
- `duration = 1.0` (seconds): the duration of the time-step.
- `T` (°C): air temperature
- `Wind` (m s-1): wind speed
- `P = 101.325` (kPa): air pressure. The default value is at 1 atm, *i.e.* the mean sea-level
atmospheric pressure on Earth.
- `Rh = rh_from_vpd(VPD,eₛ)` (0-1): relative humidity
- `Precipitations=0.0` (mm): precipitations from atmosphere (*i.e.* rain, snow, hail, etc.)
- `Cₐ` (ppm): air CO₂ concentration
- `e = vapor_pressure(T,Rh)` (kPa): vapor pressure
- `eₛ = e_sat(T)` (kPa): saturated vapor pressure
- `VPD = eₛ - e` (kPa): vapor pressure deficit
- `ρ = air_density(T, P, constants.Rd, constants.K₀)` (kg m-3): air density
- `λ = latent_heat_vaporization(T, constants.λ₀)` (J kg-1): latent heat of vaporization
- `γ = psychrometer_constant(P, λ, constants.Cₚ, constants.ε)` (kPa K−1): psychrometer "constant"
- `ε = atmosphere_emissivity(T,e,constants.K₀)` (0-1): atmosphere emissivity
- `Δ = e_sat_slope(meteo.T)` (0-1): slope of the saturation vapor pressure at air temperature
- `clearness::A = 9999.9` (0-1): Sky clearness
- `Ri_SW_f::A = 9999.9` (W m-2): Incoming short wave radiation flux
- `Ri_PAR_f::A = 9999.9` (W m-2): Incoming PAR flux
- `Ri_NIR_f::A = 9999.9` (W m-2): Incoming NIR flux
- `Ri_TIR_f::A = 9999.9` (W m-2): Incoming TIR flux
- `Ri_custom_f::A = 9999.9` (W m-2): Incoming radiation flux for a custom waveband

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

# function Atmosphere(nt::NamedTuple{names}) where {names}
#     Atmosphere{names}(nt)
# end

function Atmosphere(;
    T, Wind, Rh, date=Dates.now(), duration=1.0, P=101.325,
    Precipitations=0.0,
    Cₐ=400.0, e=vapor_pressure(T, Rh), eₛ=e_sat(T), VPD=eₛ - e,
    ρ=air_density(T, P), λ=latent_heat_vaporization(T),
    γ=psychrometer_constant(P, λ), ε=atmosphere_emissivity(T, e),
    Δ=e_sat_slope(T), clearness=9999.9, Ri_SW_f=9999.9, Ri_PAR_f=9999.9,
    Ri_NIR_f=9999.9, Ri_TIR_f=9999.9, Ri_custom_f=9999.9,
    args...
)

    # Checking some values:
    if Wind <= 0
        @warn "Wind should always be > 0, forcing it to 1e-6"
        Wind = 1e-6
    end

    if Rh <= 0
        @warn "Rh should always be > 0, forcing it to 1e-6"
        Rh = 1e-6
    end

    if Rh > 1
        if 1 < Rh < 100
            @warn "Rh should be 0 < Rh < 1, assuming it is given in % and dividing by 100"
            Rh /= 100
        else
            @error "Rh should be 0 < Rh < 1, and its value is $(Rh)"
        end
    end

    if clearness != 9999.9 && (clearness <= 0 || clearness > 1)
        @error "clearness should always be 0 < clearness < 1"
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

Base.getproperty(mnt::Atmosphere, s::Symbol) = getproperty(getfield(mnt, :nt), s)

# This is for the Tables.jl interface:
Base.getindex(mnt::Atmosphere, i::Int) = getfield(getfield(mnt, :nt), i)
Base.getindex(mnt::Atmosphere, i::Symbol) = getfield(getfield(mnt, :nt), i)
function Base.indexed_iterate(mnt::Atmosphere, i::Int, state=1)
    Base.indexed_iterate(getfield(mnt, :nt), i, state)
end


function show_long_format_row(t::Atmosphere, limit=false)
    length(t) == 0 && return
    nt = NamedTuple(t)
    if limit && length(nt) > 10
        nt = NamedTuple{keys(nt)[1:10]}(values(nt)[1:10])
        join([string(k, "=", v) for (k, v) in pairs(nt)], ", ") * " ..."
    else
        join([string(k, "=", v) for (k, v) in pairs(nt)], ", ")
    end
end