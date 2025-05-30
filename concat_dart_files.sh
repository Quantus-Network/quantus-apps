#!/bin/bash

# Define the output file
output_file="all_packages_dart_files.txt"

# Remove the output file if it already exists to start fresh
rm -f "$output_file"

# Find all .dart files in the specified package directories and their subdirectories
# Exclude 'generated' subdirectories within each package's 'lib' folder
# For each file, print its path as a header and then its content into the output file
find ./mobile-app/lib ./quantus_sdk/lib ./app/lib -name "*.dart" \
  -not -path "./mobile-app/lib/generated/*" \
  -not -path "./quantus_sdk/lib/generated/*" \
  -not -path "./app/lib/generated/*" \
  -print0 | while IFS= read -r -d $'\0' file; do
  echo "--- FILE: ${file} ---" >> "$output_file"
  cat "${file}" >> "$output_file"
  echo -e "\n" >> "$output_file" # Add a newline for separation
done

echo "All .dart files from specified packages have been concatenated into $output_file" 