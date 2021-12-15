import argparse
import pathlib
import yaml


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--builds", required=True,  help="builds YAML with state names given by the 'division' attribute")
    parser.add_argument("--descriptions-directory", required=True, help="directory to store state-specific description files")
    # parser.add_argument("--revised-builds", required=True, help="builds YAML modified to include custom descriptions")

    args = parser.parse_args()

    # Load builds YAML.
    with open(args.builds, "r") as fh:
        builds = yaml.load(fh, Loader=yaml.FullLoader)
    
    # stateList = builds["builds"].keys()
    # print (f"{stateList}")
    
    # Remove USA and NS3 builds which do not have "division"
    builds["builds"].pop("USA")
    builds["builds"].pop("NS3")
    
    # Collect a list of states/territories.
    states_by_build = {build: attributes["division"] for build, attributes in builds["builds"].items()}

    # Create the directory for state-level description files.
    descriptions_directory = pathlib.Path(args.descriptions_directory)
    descriptions_directory.mkdir(exist_ok=True)

    for build, state in states_by_build.items():
        # Define path to state-level description file.
        build_descriptions_path = descriptions_directory / pathlib.Path(f"{build}_description.md")

        # Write a basic description of the analysis that can be manually customized.
        with open(build_descriptions_path, "w") as oh:
            oh.write(f"## SARS-CoV-2 analysis with {state}-focused subsampling\n")
            oh.write(f"This analysis focuses on SARS-CoV-2 sequences available from {state} with additional sequences from the rest of the USA selected by genetic similarity to the state-level sequences. Additional global context is provided by evenly sampling sequences from major global regions across time.\n\n")
            oh.write(f"[MicrobeTrace](https://microbetrace.cdc.gov/MicrobeTrace/) edge lists for this tree can be downloaded from [https://github.com/CDCgov/spheres-auspice-data/tree/master/microbetrace](https://raw.githubusercontent.com/CDCgov/spheres-auspice-data/master/microbetrace/distance-{build}.csv.xz)for input into MicrobeTrace with your metadata for network visualization and exploration.\n\n")
            oh.write(f"[Auspice](https://auspice.us/) json files for this tree can be downloaded from [https://github.com/CDCgov/spheres-auspice-data/tree/master/auspice](https://raw.githubusercontent.com/CDCgov/spheres-auspice-data/master/auspice/ncov_{build}.tar.xz).\n\n")
            
        # # Update the YAML to include the custom build descriptions.
        # builds["builds"][build]["description"] = str(build_descriptions_path)

    # # # Save revised builds YAML with custom description paths.
    # # with open(args.revised_builds, "w") as oh:
        # # yaml.dump(builds, oh, default_flow_style=False)
