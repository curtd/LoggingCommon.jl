using Documenter

using Pkg
docs_dir = joinpath(@__DIR__, "..")
project_dir = isempty(ARGS) ? @__DIR__() : joinpath(pwd(), ARGS[1])
Pkg.activate(project_dir)

using LoggingCommon

DocMeta.setdocmeta!(LoggingCommon, :DocTestSetup, :(using LoggingCommon); recursive=true)

makedocs(;
    modules=[LoggingCommon],
    authors="Curt Da Silva",
    repo="https://github.com/curtd/LoggingCommon.jl/blob/{commit}{path}#{line}",
    sitename="LoggingCommon.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://curtd.github.io/LoggingCommon.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "API" => "api.md"
    ],
    warnonly=:missing_docs
)

deploydocs(;
    repo="github.com/curtd/LoggingCommon.jl.git",
    devbranch="main", push_preview=true
)
