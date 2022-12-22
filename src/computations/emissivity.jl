"""
    atmosphere_emissivity(Tₐ,eₐ)

Emissivity of the atmoshpere at a given temperature and vapor pressure.

# Arguments

- `Tₐ` (°C): air temperature
- `eₐ` (kPa): air vapor pressure
- `K₀` (°C): absolute zero

# Examples

```julia
Tₐ = 20.0
VPD = 1.5
atmosphere_emissivity(Tₐ, vapor_pressure(Tₐ,VPD))
```

# References

Leuning, R., F. M. Kelliher, DGG de Pury, et E.-D. SCHULZE. 1995. Leaf nitrogen,
photosynthesis, conductance and transpiration: scaling from leaves to canopies ». Plant,
Cell & Environment 18 (10): 1183‑1200.
"""
function atmosphere_emissivity(Tₐ, eₐ, K₀)
    0.642 * (eₐ * 100 / (Tₐ - K₀))^(1 / 7)
end

function atmosphere_emissivity(Tₐ, eₐ)
    atmosphere_emissivity(Tₐ, eₐ, Constants().K₀)
end
