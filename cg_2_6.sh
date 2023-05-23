#!/bin/env bash
#SBATCH -c 4

julia -p 4 compute_gram_matrix.jl 