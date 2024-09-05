#!/usr/bin/python3
#
# Copyright (c) 2017, United States Government, as represented by the
# Administrator of the National Aeronautics and Space Administration.
#
# All rights reserved.
#
# The Astrobee platform is licensed under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with the
# License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
"""
Generates the groundtruth map and groundtruth bagfile containing groundtruth 
localization estimates for a given input bagfile.
Also tests the input bagfile against a provided localization map and plots the 
results compared with the newly created groundtruth.
"""

import argparse
import os
import shutil
import sys

import localization_common.utilities as lu
import make_map

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("bagfile", help="Input bagfile to generate groundtruth for.")
    parser.add_argument(
        "base_surf_map",
        help="Existing map to use as basis for groundtruth.  Should largely overlap area covered in input bagfile.",
    )
    parser.add_argument(
        "--loc-map",
        default="",
        help="Full path to Localization map for bagfile to test localization performance. If not passed the localization test is not run",
    )
    parser.add_argument(
        "-o", "--output-directory", default="groundtruth_creation_output"
    )
    parser.add_argument(
        "-i",
        "--image-topic",
        default="/mgt/img_sampler/nav_cam/image_record",
        help="Image topic.",
    )
    parser.add_argument(
        "-m",
        "--map-name",
        default=None,
        help="Prefix for generated map names. Defaults to bagfile name.",
    )
    parser.add_argument(
        "-l",
        "--max-low-movement-mean-distance",
        type=float,
        default=0.09,
        help="Threshold for sequential image removal, the higher the more images removed.",
    )
    parser.add_argument(
        "--generate-image-features",
        dest="generate_image_features",
        action="store_true",
        help="Generate image features instead of using image features msgs from bagfile.",
    )
    parser.add_argument(
        "--no-histogram-equalization",
        dest="histogram_equalization",
        action="store_false",
        help="Do not perform histogram equalization on images for map construction.",
    )

    args = parser.parse_args()
    if not os.path.isfile(args.bagfile):
        print("Bag file " + args.bagfile + " does not exist.")
        sys.exit()
    if not os.path.isfile(args.base_surf_map):
        print("Base surf map " + args.base_surf_map + " does not exist.")
        sys.exit()
    if args.loc_map == "":
        print("Not running map localization comparison part that part")
    elif not os.path.isfile(args.loc_map):
        print("Loc map does not exist")
        sys.exit()
    if os.path.isdir(args.output_directory):
        print("Output directory " + args.output_directory + " already exists.")
        sys.exit()

    bagfile = os.path.abspath(args.bagfile)
    base_surf_map = os.path.abspath(args.base_surf_map)

    os.mkdir(args.output_directory)
    os.chdir(args.output_directory)

    map_name = args.map_name
    bag_prefix = lu.basename(bagfile)
    if not args.map_name:
        map_name = bag_prefix + "_groundtruth"

    make_map.make_map(
        bagfile,
        map_name,
        args.histogram_equalization,
        args.max_low_movement_mean_distance,
        base_surf_map,
    )

    groundtruth_bag = map_name + ".bag"
    groundtruth_map_file = map_name + ".teblid512.vocabdb.map"
    groundtruth_pdf = "groundtruth.pdf"
    groundtruth_csv = "groundtruth.csv"
    make_groundtruth_command = (
        "rosrun localization_analysis run_offline_replay_and_plot_results.py "
        + bagfile
        + " "
        + groundtruth_map_file
        + " -i "
        + args.image_topic
        + " -o "
        + groundtruth_bag
        + " --loc-output-file "
        + "loc_"
        + groundtruth_pdf
        + " --vio-output-file "
        + "vio_"
        + groundtruth_pdf
        + " --loc-results-csv-file "
        + "loc_"
        + groundtruth_csv
        + " --vio-results-csv-file "
        + "vio_"
        + groundtruth_csv
        + " --generate-image-features"
    )
    lu.run_command_and_save_output(make_groundtruth_command, "make_groundtruth.txt")
    os.rename(
        "run_offline_replay_command.txt", "groundtruth_run_offline_replay_command.txt"
    )

    if args.loc_map != "":
        loc_results_bag = bag_prefix + "_results.bag"
        loc_pdf = "loc_results.pdf"
        loc_csv = "loc_results.csv"
        get_loc_results_command = (
            "rosrun localization_analysis run_offline_replay_and_plot_results.py "
            + bagfile
            + " "
            + args.loc_map
            + " -i "
            + args.image_topic
            + " -o "
            + loc_results_bag
            + " --loc-output-file "
            + "loc_"
            + loc_pdf
            + " --vio-output-file "
            + "vio_"
            + loc_pdf
            + " --loc-results-csv-file "
            + "loc_"
            + loc_csv
            + " --vio-results-csv-file "
            + "vio_"
            + loc_csv
            + " -g "
            + groundtruth_bag
        )
        if args.generate_image_features:
            get_loc_results_command += " --generate-image-features"
        lu.run_command_and_save_output(get_loc_results_command, "get_loc_results.txt")
        os.rename(
            "run_offline_replay_command.txt", "loc_run_offline_replay_command.txt"
        )
