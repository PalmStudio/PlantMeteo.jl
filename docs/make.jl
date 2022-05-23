using PlantMeteo
using Documenter

DocMeta.setdocmeta!(PlantMeteo, :DocTestSetup, :(using PlantMeteo); recursive=true)

makedocs(;
    modules=[PlantMeteo],
    authors="remi.vezy <VEZY@users.noreply.github.com> and contributors",
    repo="https://github.com/VEZY/PlantMeteo.jl/blob/{commit}{path}#{line}",
    sitename="PlantMeteo.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://VEZY.github.io/PlantMeteo.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/VEZY/PlantMeteo.jl",
    devbranch="main",
)
