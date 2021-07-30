import argparse, csv, sys, pathlib, re, copy

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--colors", required=True, help="name of the base colors file")
    parser.add_argument("--colors-directory", required=True, help="directory to store state-specific colors files")

    args = parser.parse_args()

    # Load the base colors file.
    colors = []
    divisions = []
    with open(args.colors, 'r') as colors_tsv:
        tsv_reader = csv.reader(colors_tsv, delimiter="\t")
        for row in tsv_reader:
            colors.append(row)
            type = row[0]
            if type == "division":
                divisions.append(row)
                
    # Create the directory for state-level color files.
    colors_directory = pathlib.Path(args.colors_directory)
    colors_directory.mkdir(exist_ok=True)
                
    #Build state specific files
    for division in divisions:

        state_colors = copy.deepcopy(colors)
        state_colors.remove(division)
        state_colors.insert(0, division)
        
        state = division[1]
        state = state.lower()
        state = state.replace(" ", "-")
        build_colors_path = colors_directory / pathlib.Path(f"{state}_colors.tsv")
        
        with open(build_colors_path, mode = "w") as outfile:
            tsv_writer = csv.writer(outfile, delimiter = "\t")
            for row in state_colors:
                tsv_writer.writerow(row)
        