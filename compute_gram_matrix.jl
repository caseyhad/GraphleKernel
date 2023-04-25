using JLD2, MolecularGraphKernels, MolecularGraph

@load "users\\caseyhad\\metagraphs.jld2" metagraphs

gram_matrix_2_6 = gram_matrix(connected_graphlet, metagraphs; n=2:6, normalize = true)

@save "users\\caseyhad\\cg_gram_matrix_2_6.jld2" gram_matrix_2_6