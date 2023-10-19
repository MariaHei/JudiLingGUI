include("repository.jl")

fun = string(
"# First, define a function to load the custom semantic vectors
function get_vectors_duplicates(vector_dataframe, word_subset)
    \"\"\"Get semantic matrix with colnames for a .csv.gz file, words in word_subset can occur multiple times

    Arguments:
    filepath: file with semantic vectors, in .csv.gz format
    word_subset: DataFrame with (non necessarily unique) words which should have a semantic vector in the semantic matrix
    sem_name_col: column in word_subset with the words

    Returns:
    S: semantic matrix
    semvecs_col: all words present in the semantic matrix, in the same order as in the semantic matrix
    \"\"\"

    semvecs_col = vector_dataframe[:,1]
    vector_dataframe = vector_dataframe[:,2:end]

    # convert to semantic matrix
    semvecs = Matrix(vector_dataframe);

    word_subset = word_subset[in.(word_subset, Ref(semvecs_col))]
    new_length = length(word_subset)

    S = zeros(Float64, (new_length, size(semvecs, 2)))
    rownames = []
    for i in 1:length(word_subset)
        w = word_subset[i]
        if w in semvecs_col
            S[i,:] = semvecs[semvecs_col .== w,:][1,:]
            append!(rownames, [w])
        end
    end

    S[1:length(rownames),:], rownames
end
")

function to_code(model)
if model.current_data[] in model.datasets[]
    filepath = repository_get_filepath(model.current_data[])
else
    filepath = temporary_repository_get_filepath(model.current_data[])
end

if model.current_semantic_vectors[] != "simulated"
filepath_semvecs = temporary_repository_get_filepath(model.current_semantic_vectors[]);
S_string = string(
fun, "\n\n",
"# Now read in the semantic vectors\n",
"semvecs = CSV.File(\"",filepath_semvecs,"\") |> DataFrame \n
# bring the semantic vectors into the order of the dataset and only keep semantic vectors which are in the dataset
S, words = get_vectors_duplicates(semvecs, dataset[:,\"",model.wordform_col[],"\"]); \n",
"# Exclude all wordforms from the dataset for which no semantic vectors are available
if !all(words == dataset[:,\"",model.wordform_col[],"\"])
    dataset = filter(row -> row[\"",model.wordform_col[],"\"] in words, dataset)
end \n\n")
package_string = "using Mmap, CodecZlib, "
else
S_string = string("S = JudiLing.make_S_matrix(dataset,\n\t",
model.base_columns_selected[], ",\n\t",
model.inflectional_columns_selected[], ",\n\t ncol=",model.ncol[], ")", "\n\n")
package_string = "using "
end

if ismissing(my_ldl_model.measures)
    learn_paths_string = "res_learn = JudiLing.learn_paths(dataset,
                                    cue_obj,
                                    S,
                                    F,
                                    Chat,
                                    threshold = threshold)
alg_acc = JudiLing.eval_acc(res_learn, cue_obj)
print(alg_acc)"
package_string = string(package_string, "JudiLing, CSV, DataFrames\n\n ")
else
    learn_paths_string = "max_t = JudiLing.cal_max_timestep(dataset, dataset, tgt_col)
res_learn, gpi_learn, rpi_learn = JudiLingMeasures.learn_paths_rpi(
                                            dataset,
                                            dataset,
                                            cue_obj.C,
                                            S,
                                            F,
                                            Chat,
                                            cue_obj.A,
                                            cue_obj.i2f,
                                            cue_obj.f2i, # api changed in 0.3.1
                                            gold_ind = cue_obj.gold_ind,
                                            Shat_val = Shat,
                                            check_gold_path = true,
                                            max_t = max_t,
                                            max_can = 10,
                                            grams = grams,
                                            threshold = threshold,
                                            tokenized = false,
                                            sep_token = \"_\",
                                            keep_sep = false,
                                            target_col = tgt_col,
                                            issparse = :dense,
                                            verbose = true)
alg_acc = JudiLing.eval_acc(res_learn, cue_obj)
print(alg_acc)
measures = JudiLingMeasures.compute_all_measures(dataset, # the data of interest
                             cue_obj, # the cue_obj of the training data
                             cue_obj, # the cue_obj of the data of interest
                             Chat, # the Chat of the data of interest
                             S, # the S matrix of the data of interest
                             Shat, # the Shat matrix of the data of interest
                             F, # the comprehension matrix
                             G, # the production matrix
                             res_learn, # the output of learn_paths for the data of interest
                             gpi_learn, # the gpi_learn object of the data of interest
                             rpi_learn, # the rpi_learn object of the data of interest
                             calculate_production_uncertainty=false);"
package_string = string(package_string, "JudiLing, CSV, DataFrames, JudiLingMeasures\n\n ")
end

s = string(package_string,

"# Load the dataframe \n",
"dataset = CSV.File(\"", filepath, "\") |> DataFrame", "\n\n",

"# Load the simulated semantic vectors \n",
S_string,

"# Create the cue object \n",
"tgt_col = \"", model.target_column_selected[],"\"\n",
"grams = ", model.ngram[], "\n",
"cue_obj = JudiLing.make_cue_matrix(dataset, grams=grams", ", target_col=tgt_col",")", "\n\n",

"# Calculate the mapping matrices \n",
"F = JudiLing.make_transform_matrix(cue_obj.C, S)", "\n",
"G = JudiLing.make_transform_matrix(S, cue_obj.C)", "\n\n",

"# Calculate the predicted matrices \n",
"Shat = cue_obj.C * F","\n",
"Chat = S * G","\n\n",

"# Compute comprehension accuracy \n",
"comp_acc = JudiLing.eval_SC(Shat, S, dataset, tgt_col)","\n",
"print(comp_acc)","\n\n",

"# Compute production algorithm accuracy \n",
"threshold = ", model.production_threshold[],"\n",
learn_paths_string)

open("public/code.jl" , "w") do io
write("public/code.jl", s)
end
s
end
