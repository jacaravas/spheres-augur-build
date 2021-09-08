# Rules for SPHERES Augur

# Link this file in builds.yaml file using:
# custom_rules:
#   - spheres_profile/spheres_custom_rules.smk
#
# And add the output to your Snakefile rule all/input using 
# rule all: 
#    input:
#       distance = expand("microbetrace/distance-{build_name}.csv", build_name=BUILD_NAMES, ext=config["auspice_json_prefix"])



rule mask_ambiguous:
   message: "Masking ambiguous sites and gaps with N for augur distance calculation"
   input:
      subsampled_sequences = "results/{build_name}/aligned.fasta"
   output:
      masked_alignment = "results/{build_name}/{build_name}_masked_subsampled_sequences.fasta"
   log:
      "logs/mask_ambiguous_sites_{build_name}.txt"
   conda: config["conda_environment"]
   shell:
      """
      python3 spheres_profile/mask_ambiguous_sites.py \
         --alignment {input.subsampled_sequences} \
         --output {output.masked_alignment} 2>&1 | tee {log}
      """
      

rule calculate_distance:
   message: "Calculating distance using augur distance, not counting mismatches at ambiguous and gap sites"
   input:
      tree = "results/{build_name}/tree.nwk",
      masked_alignment = "results/{build_name}/{build_name}_masked_subsampled_sequences.fasta",
      date_annotations= "results/{build_name}/branch_lengths.json"
   output:
      distance = "results/{build_name}/distance-{build_name}.json"
   log:
      "logs/calculate_distance_{build_name}.txt"
   conda: config["conda_environment"]
   shell:
      """
      augur distance \
         --tree {input.tree} \
         --alignment {input.masked_alignment} \
         --output {output.distance} \
         --gene-names GENOME \
         --attribute-name default \
         --map spheres_profile/ignore_masked_map.json \
         --compare-to pairwise \
         --date-annotations {input.date_annotations} \
         2>&1 | tee {log}
      """
      
rule reformat_distance:
   message: "Converting JSON format distance matrices to CSV"
   input:
      matrix = "results/{build_name}/distance-{build_name}.json"
   output:
      output = "microbetrace/distance-{build_name}.csv"
   # log:
   conda: config["conda_environment"]
   shell:
      """
      python3 spheres_profile/reformat_matrix.py \
         --matrix {input.matrix} \
         --output {output.output}
      """
      
      
