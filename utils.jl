using Mmap, CodecZlib, CSV, DataFrames

function get_vectors_duplicates(vector_dataframe, word_subset)
    """Get semantic matrix with colnames for a .csv.gz file, words in word_subset can occur multiple times

    Arguments:
    filepath: file with semantic vectors, in .csv.gz format
    word_subset: DataFrame with (non necessarily unique) words which should have a semantic vector in the semantic matrix
    sem_name_col: column in word_subset with the words

    Returns:
    S: semantic matrix
    semvecs_col: all words present in the semantic matrix, in the same order as in the semantic matrix
    """


    semvecs_col = vector_dataframe[:,1]

    vector_dataframe = vector_dataframe[:,2:end]

    print(vector_dataframe[1:5,1:5])

    # convert to semantic matrix
    semvecs = Matrix(vector_dataframe);

    word_subset = word_subset[in.(word_subset, Ref(semvecs_col))]
    new_length = length(word_subset)
    print(new_length)

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
