import Pkg; Pkg.add("JLD2")
import Pkg; Pkg.add("MolecularGraph")
using JLD2, MolecularGraphKernels, MolecularGraph

@load "C:\\Users\\dcase\\GraphletKernel\\metagraphs.jld2" metagraphs

gram_matrix_2_6 = gram_matrix(connected_graphlet, metagraphs; n=2:6, normalize = true)

@save "C:\\Users\\dcase\\GraphletKernel\\cg_gram_matrix_2_6.jld2" gram_matrix_2_6