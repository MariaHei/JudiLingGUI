using CSV, DataFrames

mutable struct Repository
    datasets::Dict
    data_path::String
    fileformats::Vector{String}

    function Repository(directory)
        datasets = Dict()
        for d in readdir(directory)

            if endswith(d, ".csv") | endswith(d, ".csv.gz")
                #name = replace(d, ".csv"=>"")
                datasets[d] = string(directory, "/", d)
            end
        end
        new(datasets, directory)
    end
end

cd(@__DIR__)
global temporary_filepath = "upload"
global temporary_repository = Repository(temporary_filepath)
global data_path = "data"
global repository = Repository(data_path)


function update_repository()
    repository = Repository(data_path)
end

function get(name, rep)

    filepath = rep.datasets[name]
    dataframe = CSV.File(filepath, missingstring="missing") |> DataFrame
    # for col in names(dataframe)
    #     unique_datatypes = collect(Set(append!([typeof(d) for d in dataframe[:, col]], [Missing])))
    #     dataframe[:, col] = similar(dataframe[:, col], Union{unique_datatypes...})
    #     dataframe[dataframe[:,col] .== "missing",col] .= missing
    # end
    # if name == "latin.csv"
    #     dataframe[dataframe.Tense .== "pluperfect",:Tense] .= "plpfect"
    # end
    dataframe
end

function repository_get(name)
    get(name, repository)
end

function repository_get_filepath(name)
    repository.datasets[name]
end

function repository_add(filepath, name; dataframe=missing)
    if ismissing(dataframe)
        dataframe = CSV.File(filepath) |> DataFrame
    end
    CSV.write(filepath, dataframe)
    repository = update_repository(repository)
end

function repository_get_available_datasets()
    collect(keys(repository.datasets))
end


function temporary_repository_add(file, name)
    filepath = string(temporary_filepath, "/", name)
    print(filepath)
    open(filepath , "w") do io
      write(filepath, filespayload(file).data)
    end
    print("done writing")
    global temporary_repository = Repository(temporary_filepath)
    print("done updating")
    print(temporary_repository.datasets)
    print(name)
end

function temporary_repository_get(name)
    #if name == "custom"
    #get(name, temporary_repository)
    #elseif name == "vectors"
    #name = replace(name, ".csv"=>"")
    print(name)
    print(temporary_repository.datasets)
    filepath = temporary_repository.datasets[name]
    print(filepath)
    if endswith(filepath, ".gz")
        CSV.File(transcode(GzipDecompressor,
                                Mmap.mmap(filepath))) |> DataFrame
    elseif endswith(filepath, ".csv")
        #semvecs = CSV.File(filepath) |> DataFrame
        get(name, temporary_repository)
    end
        #semvecs
    #end
end

function temporary_repository_get_filepath(name)
    #name = replace(name, ".csv"=>"")
    temporary_repository.datasets[name]
end


function reset_public_directory()
	if Filesystem.isfile("public/measures.csv")
	Filesystem.rm("public/measures.csv")
	end

	if Filesystem.isfile("public/code.jl")
	Filesystem.rm("public/code.jl")
	end
end
