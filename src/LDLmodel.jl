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

    function LDLmodel()
        new(missing, missing, missing, missing, missing, missing, missing, missing, missing, missing)
    end
end

function check_semantic_vectors_be(words, ldl_model, current_dataset, wordform_col)
    if !all(words == current_dataset[:,wordform_col])
        prev_length = size(current_dataset, 1)
        current_dataset = filter(row -> row[wordform_col[]] in words, current_dataset)
        @info all(current_dataset[:,wordform_col] .== words)
        true, prev_length - size(current_dataset,1), current_dataset
    else
        false, 0, DataSet()
    end
end

function acc_calculable(ldl_model)
    if (!ismissing(ldl_model.cue_obj) & !ismissing(ldl_model.S))
        true
    else
        false
    end
end

function calculate_comprehension_accuracy_be(ldl_model, current_dataset, target_column_selected)
    if acc_calculable(ldl_model)
        ldl_model.F = JudiLing.make_transform_matrix(ldl_model.cue_obj.C, ldl_model.S)
        ldl_model.Shat = ldl_model.cue_obj.C * ldl_model.F
        acc = JudiLing.eval_SC(ldl_model.Shat, ldl_model.S, current_dataset, target_column_selected)
        acc
    else
        missing
    end
end

function calculate_production_accuracy_be(ldl_model, current_dataset, target_column_selected)
    if acc_calculable(ldl_model)
        ldl_model.G = JudiLing.make_transform_matrix(ldl_model.S, ldl_model.cue_obj.C)
        ldl_model.Chat = ldl_model.S * ldl_model.G
        acc = JudiLing.eval_SC(ldl_model.Chat, ldl_model.cue_obj.C, current_dataset, target_column_selected)
    else
        missing
    end
end

function calculate_algo_production_accuracy_be(ldl_model,
                                               current_dataset,
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

    max_t = JudiLing.cal_max_timestep(current_dataset, current_dataset, target_column_selected)

    ldl_model.res_learn, ldl_model.gpi_learn, ldl_model.rpi_learn = JudiLingMeasures.learn_paths_rpi(
                                                                                current_dataset,
                                                                                current_dataset,
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

function calculate_measures_be(ldl_model, current_dataset)
    if ismissing(ldl_model.res_learn)
        calculate_algo_production_accuracy()
    end
    print("here1")
    ldl_model.measures = JudiLingMeasures.compute_all_measures(current_dataset, # the data of interest
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
    print("here2")

    CSV.write("public/measures.csv", ldl_model.measures)
end

function get_number_of_cues(ldl_model)
    if ismissing(ldl_model.cue_obj)
        ""
    else
        string("There are ", size(ldl_model.cue_obj.C, 2), " cues in your C matrix.")
    end
end
