#!/bin/bash

# Define the output file
output_file="mobile_app_dart_all_files.txt"

# Remove the output file if it already exists to start fresh
rm -f "$output_file"

# Find all .dart files in the current directory and its subdirectories
# For each file, print its path as a header and then its content into the output file
find ./lib -name "*.dart" -not -path "./lib/generated/*" -print0 | while IFS= read -r -d $'\0' file; do
  echo "--- FILE: ${file} ---" >> "$output_file"
  cat "${file}" >> "$output_file"
  echo -e "\n" >> "$output_file" # Add a newline for separation
done

echo "All .dart files have been concatenated into $output_file" 