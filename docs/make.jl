using PlantMeteo
using Documenter
using Dates

DocMeta.setdocmeta!(PlantMeteo, :DocTestSetup, :(using PlantMeteo, Dates); recursive=true)

makedocs(;
    modules=[PlantMeteo],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo="https://github.com/PalmStudio/PlantMeteo.jl/blob/{commit}{path}#{line}",
    sitename="PlantMeteo.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://PalmStudio.github.io/PlantMeteo.jl",
        assets=String[]
    ),
    pages=[
        "Home" => "index.md",
        "API" => "API.md"
    ]
)

deploydocs(;
    repo="github.com/PalmStudio/PlantMeteo.jl",
    devbranch="main"
)
