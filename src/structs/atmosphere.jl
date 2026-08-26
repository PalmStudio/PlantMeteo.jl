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

With the default `check=true`, core values are validated before derived values
are computed: `Wind` must be non-negative, `Rh` must be in `[0, 1]`, and `P` must
be in the terrestrial `]85, 110[` kPa range. Invalid values throw an error;
the constructor never clamps wind, guesses percent humidity, or converts
pressure. Use [`normalize_weather_import`](@ref) explicitly at an import
boundary when source units differ.

`clearness` and `Ri_*_f` fields are present only when supplied. Pass `missing`
when the source explicitly contains a missing value. Omitting one of these
keywords means that the forcing is structurally absent; `Inf` is not used as an
absence marker. Physical zeros are valid for calm wind, dry air, darkness, and
zero incoming radiation.

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

struct _UnsetAtmosphereValue end
const _UNSET_ATMOSPHERE_VALUE = _UnsetAtmosphereValue()

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
    e=_UNSET_ATMOSPHERE_VALUE, eₛ=_UNSET_ATMOSPHERE_VALUE,
    VPD=_UNSET_ATMOSPHERE_VALUE, ρ=_UNSET_ATMOSPHERE_VALUE,
    λ=_UNSET_ATMOSPHERE_VALUE, γ=_UNSET_ATMOSPHERE_VALUE,
    ε=_UNSET_ATMOSPHERE_VALUE, Δ=_UNSET_ATMOSPHERE_VALUE,
    clearness=_UNSET_ATMOSPHERE_VALUE,
    Ri_SW_f=_UNSET_ATMOSPHERE_VALUE,
    Ri_PAR_f=_UNSET_ATMOSPHERE_VALUE,
    Ri_NIR_f=_UNSET_ATMOSPHERE_VALUE,
    Ri_TIR_f=_UNSET_ATMOSPHERE_VALUE,
    Ri_custom_f=_UNSET_ATMOSPHERE_VALUE,
    args...
) where {D1<:Dates.AbstractTime}

    for p in pairs((; T, Wind, P, Rh, date, duration))
        if ismissing(p.second)
            throw(ArgumentError("$(p.first) must be different than missing"))
        end
    end

    if check
        _validate_atmosphere_core(T, Wind, Rh, P)
        _validate_optional_atmosphere_forcing(:clearness, clearness)
        for (name, value) in pairs((; Ri_SW_f, Ri_PAR_f, Ri_NIR_f, Ri_TIR_f, Ri_custom_f))
            _validate_optional_atmosphere_forcing(name, value)
        end
    end

    # Core values are validated before any derived value is computed. `check=false`
    # deliberately skips validation only; it never changes the values supplied by the caller.
    e = e === _UNSET_ATMOSPHERE_VALUE ? vapor_pressure(T, Rh; check=false) : e
    eₛ = eₛ === _UNSET_ATMOSPHERE_VALUE ? e_sat(T) : eₛ
    VPD = VPD === _UNSET_ATMOSPHERE_VALUE ? eₛ - e : VPD
    ρ = ρ === _UNSET_ATMOSPHERE_VALUE ? air_density(T, P; check=false) : ρ
    λ = λ === _UNSET_ATMOSPHERE_VALUE ? latent_heat_vaporization(T) : λ
    γ = γ === _UNSET_ATMOSPHERE_VALUE ? psychrometer_constant(P, λ; check=false) : γ
    ε = ε === _UNSET_ATMOSPHERE_VALUE ? atmosphere_emissivity(T, e) : ε
    Δ = Δ === _UNSET_ATMOSPHERE_VALUE ? e_sat_slope(T) : Δ

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
            Δ=Δ
        )

    promoted_params = (; zip(keys(params_same_type), promote(values(params_same_type)...))...)
    optional_params = _atmosphere_optional_forcing(
        typeof(promoted_params.T);
        clearness,
        Ri_SW_f,
        Ri_PAR_f,
        Ri_NIR_f,
        Ri_TIR_f,
        Ri_custom_f,
    )

    Atmosphere(
        (;
        date=date,
        duration=duration,
        # We promote the types that we know should share the same type:
        promoted_params...,
        optional_params...,
        args...)
    )
end

function _validate_finite_real(name::Symbol, value)
    value isa Real || throw(ArgumentError("$name must be a real value, got $(repr(value))"))
    isfinite(value) || throw(ArgumentError("$name must be finite, got $value"))
    return nothing
end

function _validate_atmosphere_core(T, Wind, Rh, P)
    for (name, value) in pairs((; T, Wind, Rh, P))
        _validate_finite_real(name, value)
    end

    Wind >= 0.0 || throw(ArgumentError("Wind speed ($Wind) must be non-negative"))
    0.0 <= Rh <= 1.0 || throw(ArgumentError("Relative humidity ($Rh) must be between 0 and 1"))
    85.0 < P < 110.0 || throw(ArgumentError("Air pressure ($P) is not in the 85-110 kPa earth range"))
    return nothing
end

function _validate_optional_atmosphere_forcing(name::Symbol, value)
    value === _UNSET_ATMOSPHERE_VALUE && return nothing
    ismissing(value) && return nothing
    _validate_finite_real(name, value)

    if name === :clearness
        0.0 <= value <= 1.0 || throw(ArgumentError("clearness ($value) must be between 0 and 1"))
    else
        value >= 0.0 || throw(ArgumentError("$name ($value) must be non-negative"))
    end
    return nothing
end

function _atmosphere_optional_forcing(
    numeric_type::Type;
    clearness,
    Ri_SW_f,
    Ri_PAR_f,
    Ri_NIR_f,
    Ri_TIR_f,
    Ri_custom_f,
)
    names = Symbol[]
    values_ = Any[]
    for (name, value) in pairs((; clearness, Ri_SW_f, Ri_PAR_f, Ri_NIR_f, Ri_TIR_f, Ri_custom_f))
        value === _UNSET_ATMOSPHERE_VALUE && continue
        value === nothing && throw(ArgumentError("$name cannot be `nothing`; omit it when absent or use `missing` for an explicit missing value"))
        push!(names, name)
        push!(values_, ismissing(value) ? missing : convert(numeric_type, value))
    end
    return NamedTuple{Tuple(names)}(Tuple(values_))
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
