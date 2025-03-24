#!/bin/bash

# Static boundary for multipart-encoded data
boundary="6bd84d1042f94cc7baf9ca62779f64d7"
# DataDog Site
DD_SITE="datadoghq.com"
# Create the multipart message for event JSON and mapping file
create_multipart_message() {
    local temp_file=$(mktemp)
    local boundary=$1
    local event_data=$2
    local mapping_file_path=$3

    {
        # Start with event JSON
        echo "--$boundary"
        echo 'Content-Disposition: form-data; name="event"; filename="event.json"'
        echo 'Content-Type: application/json; charset=utf-8'
        echo
        echo "$event_data"

        # Now the mapping file
        echo "--$boundary"
        echo 'Content-Disposition: form-data; name="jvm_mapping_file"; filename="jvm_mapping"'
        echo 'Content-Type: text/plain'
        echo
        cat "$mapping_file_path"  # Embed file content here

        # Closing boundary
        echo "--$boundary--"
    } > "$temp_file"

    echo "$temp_file"
}
upload_deobfuscation_mapping_to_datadog() {
    skip=false

    if [[ -z $DD_API_KEY ]]; then
        echo "WARNING: Missing DataDog API key. Skipping code deobfuscation mapping file upload to DataDog."
        skip=true
    fi

    # Unzip deobfuscation script output
    unzip "$DEOBFUSCATION_SCRIPT_OUTPUT_LOCATION" -d deobfuscation_mapping_files

    # Remove any __MACOSX files and unnecessary directory layers if they exist
    find deobfuscation_mapping_files -name "__MACOSX" -exec rm -rf {} +
    mv deobfuscation_mapping_files/*/* deobfuscation_mapping_files/ 2>/dev/null

    if ! cd deobfuscation_mapping_files; then
        echo "WARNING: Could not access deobfuscation_mapping_files directory. Skipping upload to DataDog."
        skip=true
    fi

    # Check for required files
    if [[ ! -f mapping.txt ]]; then
        echo "WARNING: Missing mapping.txt file. Skipping code deobfuscation mapping file upload to DataDog."
        skip=true
    fi

    if [[ ! -f data_dog_metadata.json ]]; then
        echo "WARNING: Missing data_dog_metadata.json file. Skipping code deobfuscation mapping file upload to DataDog."
        skip=true
    fi

      # Proceed with the upload only if skip is false
    if [[ $skip == false ]]; then
        # Read metadata from data_dog_metadata.json
        build_id=$(extract_string_value_from_json "$(cat data_dog_metadata.json)" 'build_id')
        service_name=$(extract_string_value_from_json "$(cat data_dog_metadata.json)" 'service_name')
        version=$(extract_string_value_from_json "$(cat data_dog_metadata.json)" 'version')

        if [[ -z $build_id || -z $service_name || -z $version ]]; then
            echo "ERROR: Missing required metadata (build_id, service_name, or version) in data_dog_metadata.json."
            cd ..
            rm -rf deobfuscation_mapping_files
            return
        fi
        # Prepare JSON payload
        event_json=$(cat <<EOF
{
    "build_id": "$build_id",
    "service": "$service_name",
    "type": "jvm_mapping_file",
    "version": "$version"
}
EOF
        )

        # Generate the multipart message body
        multipart_file=$(create_multipart_message "$boundary" "$event_json" "mapping.txt")

        # Set the DataDog API URL
        url="https://sourcemap-intake.datadoghq.com/api/v2/srcmap"

        # Send the request with curl
        response=$(curl -w "%{http_code}" -o /dev/null -X POST "$url" \
            -H "Content-Type: multipart/form-data; boundary=$boundary" \
            -H "Accept-Encoding: gzip" \
            -H "dd-evp-origin: dd-sdk-android-gradle-plugin" \
            -H "dd-evp-origin-version: 1.13.0" \
            -H "dd-api-key: $DD_API_KEY" \
            --data-binary "@$multipart_file")

        # Check response status
        if [[ $response -eq 202 ]]; then
            echo "Mapping file uploaded successfully to DataDog!"
        else
            echo "Failed to upload mapping file to DataDog. Status code: $response"
        fi
    fi

    # Cleanup
    cd ..
    rm -rf deobfuscation_mapping_files

    # Clean up the temporary file
    rm -f "$multipart_file"
}