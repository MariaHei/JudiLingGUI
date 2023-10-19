using CSV, DataFrames
using JudiLing
using JudiLingMeasures

include("utils.jl")
include("repository.jl")
include("output.jl")

mutable struct LDLmodel
    S::Union{Missing,Matrix,JudiLing.SparseMatrixCSC}
    cue_obj::Union{Missing,JudiLing.Cue_Matrix_Struct}
    F::Union{Missing,Matrix,JudiLing.SparseMatrixCSC}
    G::Union{Missing,Matrix,JudiLing.SparseMatrixCSC}
    Shat::Union{Missing,Matrix,JudiLing.SparseMatrixCSC}
    Chat::Union{Missing,Matrix,JudiLing.SparseMatrixCSC}
    res_learn::Union{Missing,Array{Array{JudiLing.Result_Path_Info_Struct,1},1}}
    gpi_learn::Union{Missing,Vector{JudiLing.Gold_Path_Info_Struct}}
    rpi_learn::Union{Missing,Vector{JudiLing.Gold_Path_Info_Struct}}
    measures::Union{Missing,DataFrame}
    dataset::Union{Missing, DataFrame}

    function LDLmodel()
        new(missing, missing, missing, missing, missing, missing, missing, missing, missing, missing, missing)
    end
end

function get_dataset_be(ldl_model, file, dataname)
    if ismissing(file)
        dataset = repository_get(dataname)
    else
        dataname = filename(filespayload(file))
        temporary_repository_add(file, dataname)
        dataset = temporary_repository_get(dataname)
    end
    ldl_model.dataset = dataset
    dataname
end

function set_semantic_vectors_be(ldl_model, file,
                                base_columns_selected,
                                inflectional_columns_selected,
                                ncol,
                                current_semantic_vectors,
                                wordform_col)
    if ismissing(file)
        ldl_model.S = JudiLing.make_S_matrix(ldl_model.dataset,
                                            base_columns_selected,
                                            inflectional_columns_selected,
                                            ncol=ncol)
        "simulated", false, missing
    else
        current_semantic_vectors = filename(filespayload(file))
        temporary_repository_add(file, current_semantic_vectors)
        semvecs = temporary_repository_get(current_semantic_vectors)
        my_ldl_model.S, words = get_vectors_duplicates(semvecs,
                                                       ldl_model.dataset[:,wordform_col]);
        too_big, excluded, ldl_model.dataset = check_semantic_vectors_be(words, my_ldl_model,
                                                              wordform_col)

        current_semantic_vectors, too_big, excluded
    end
end

function check_semantic_vectors_be(words, ldl_model, wordform_col)
    if !all(words == ldl_model.dataset[:,wordform_col])
        prev_length = size(ldl_model.dataset, 1)
        ldl_model.dataset = filter(row -> row[wordform_col] in words, ldl_model.dataset)
        #@info all(ldl_model.dataset[:,wordform_col] .== words)
        true, prev_length - size(ldl_model.dataset,1), ldl_model.dataset
    else
        false, 0, ldl_model.dataset
    end
end

function acc_calculable(ldl_model)
    if (!ismissing(ldl_model.cue_obj) & !ismissing(ldl_model.S))
        true
    else
        false
    end
end

function calculate_comprehension_accuracy_be(ldl_model, target_column_selected)
    if acc_calculable(ldl_model)
        ldl_model.F = JudiLing.make_transform_matrix(ldl_model.cue_obj.C, ldl_model.S)
        ldl_model.Shat = ldl_model.cue_obj.C * ldl_model.F
        acc = JudiLing.eval_SC(ldl_model.Shat, ldl_model.S, ldl_model.dataset, target_column_selected)
        acc
    else
        missing
    end
end

function calculate_production_accuracy_be(ldl_model, target_column_selected)
    if acc_calculable(ldl_model)
        ldl_model.G = JudiLing.make_transform_matrix(ldl_model.S, ldl_model.cue_obj.C)
        ldl_model.Chat = ldl_model.S * ldl_model.G
        acc = JudiLing.eval_SC(ldl_model.Chat, ldl_model.cue_obj.C, ldl_model.dataset, target_column_selected)
    else
        missing
    end
end

function calculate_algo_production_accuracy_be(ldl_model,
                                               target_column_selected,
                                               production_threshold,
                                               ngram)
    if ismissing(ldl_model.Chat)
        ldl_model.G = JudiLing.make_transform_matrix(ldl_model.S, ldl_model.cue_obj.C)
        ldl_model.Chat = ldl_model.S * ldl_model.G
    end

    if ismissing(ldl_model.F)
        ldl_model.F = JudiLing.make_transform_matrix(ldl_model.cue_obj.C, ldl_model.S)
        ldl_model.Shat = ldl_model.cue_obj.C * ldl_model.F
    end

    max_t = JudiLing.cal_max_timestep(ldl_model.dataset, ldl_model.dataset, target_column_selected)

    ldl_model.res_learn, ldl_model.gpi_learn, ldl_model.rpi_learn = JudiLingMeasures.learn_paths_rpi(
                                                                                ldl_model.dataset,
                                                                                ldl_model.dataset,
                                                                                ldl_model.cue_obj.C,
                                                                                ldl_model.S,
                                                                                ldl_model.F,
                                                                                ldl_model.Chat,
                                                                                ldl_model.cue_obj.A,
                                                                                ldl_model.cue_obj.i2f,
                                                                                ldl_model.cue_obj.f2i, # api changed in 0.3.1
                                                                                gold_ind = ldl_model.cue_obj.gold_ind,
                                                                                Shat_val = ldl_model.Shat,
                                                                                check_gold_path = true,
                                                                                max_t = max_t,
                                                                                max_can = 10,
                                                                                grams = ngram,
                                                                                threshold = production_threshold,
                                                                                tokenized = false,
                                                                                sep_token = "_",
                                                                                keep_sep = false,
                                                                                target_col = target_column_selected,
                                                                                issparse = :dense,
                                                                                verbose = true,
);
    acc = JudiLing.eval_acc(ldl_model.res_learn, ldl_model.cue_obj)
    acc
end

function calculate_measures_be(ldl_model)
    if ismissing(ldl_model.res_learn)
        calculate_algo_production_accuracy()
    end
    ldl_model.measures = JudiLingMeasures.compute_all_measures(ldl_model.dataset, # the data of interest
                                                     ldl_model.cue_obj, # the cue_obj of the training data
                                                     ldl_model.cue_obj, # the cue_obj of the data of interest
                                                     ldl_model.Chat, # the Chat of the data of interest
                                                     ldl_model.S, # the S matrix of the data of interest
                                                     ldl_model.Shat, # the Shat matrix of the data of interest
                                                     ldl_model.F,
                                                     ldl_model.G,
                                                     ldl_model.res_learn, # the output of learn_paths for the data of interest
                                                     ldl_model.gpi_learn, # the gpi_learn object of the data of interest
                                                     ldl_model.rpi_learn); # the rpi_learn object of the data of interest

    CSV.write("public/measures.csv", ldl_model.measures)
end

function get_number_of_cues(ldl_model)
    if ismissing(ldl_model.cue_obj)
        ""
    else
        string("There are ", size(ldl_model.cue_obj.C, 2), " cues in your C matrix.")
    end
end
