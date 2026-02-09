using PlantMeteo
using Documenter
using Dates, Statistics

DocMeta.setdocmeta!(PlantMeteo, :DocTestSetup, :(using PlantMeteo, Dates, Statistics); recursive=true)

makedocs(;
    modules=[PlantMeteo],
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
        "Getting Started" => "getting-started.md",
        "Guides" => [
            "Weather Data Sources" => "weather-apis.md",
            "Weather Sampling" => "weather-sampling.md",
        ],
        "API" => "API.md"
    ]
)

deploydocs(;
    repo="github.com/PalmStudio/PlantMeteo.jl.git",
    devbranch="main"
)
