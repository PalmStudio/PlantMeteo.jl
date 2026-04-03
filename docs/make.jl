using PlantMeteo
using Documenter
using Dates, Statistics

DocMeta.setdocmeta!(PlantMeteo, :DocTestSetup, :(using PlantMeteo, Dates, Statistics); recursive=true)

makedocs(;
    modules=[PlantMeteo],
    checkdocs=:exports,
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo=Documenter.Remotes.GitHub("PalmStudio", "PlantMeteo.jl"),
    sitename="PlantMeteo.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://PalmStudio.github.io/PlantMeteo.jl",
        edit_link="main",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
        "Quickstart" => "quickstart.md",
        "Guides" => [
            "Getting Weather Data" => "getting-weather-data.md",
            "Open-Meteo Guide" => "open-meteo.md",
            "Core Concepts" => "core-concepts.md",
            "Daily Aggregation" => "daily-aggregation.md",
            "Weather Sampling" => "weather-sampling.md",
            "Read/Write Round Trip" => "read-write-round-trip.md",
        ],
        "Reference" => "reference.md"
    ]
)

deploydocs(;
    repo="github.com/PalmStudio/PlantMeteo.jl.git",
    devbranch="main"
)
