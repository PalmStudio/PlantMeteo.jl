using PlantMeteo
using Documenter
using Dates

DocMeta.setdocmeta!(PlantMeteo, :DocTestSetup, :(using PlantMeteo, Dates); recursive=true)

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
        "API" => "API.md"
    ]
)

deploydocs(;
    repo="github.com/PalmStudio/PlantMeteo.jl.git",
    devbranch="main"
)
