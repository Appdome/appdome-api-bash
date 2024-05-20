#!/bin/bash

upload_deobfuscation_mapping_to_crashlytics() {
    skip=false

    if [[ -z $GOOGLE_APPLICATION_CREDENTIALS ]]; then
        echo "WARNING: Missing Google authentication service file. Skipping code deobfuscation mapping file uploading to Crashlytics."
        skip=true	
    fi

    if [[ -z $APP_ID ]]; then
        echo "WARNING: Missing Firebase project app ID. Skipping code deobfuscation mapping file uploading to Crashlytics."
        skip=true	
    fi

    unzip $DEOBFUSCATION_SCRIPT_OUTPUT_LOCATION -d deobfuscation_mapping_files
    cd deobfuscation_mapping_files

    if [[ ! -f mapping.txt ]]; then
        echo "WARNING: Missing mapping.txt file. Skipping code deobfuscation mapping file uploading to Crashlytics."
        skip=true
    fi

    if [[ ! -f com_google_firebase_crashlytics_mappingfileid.xml ]]; then
        echo "WARNING: Missing com_google_firebase_crashlytics_mappingfileid.xml file. Skipping code deobfuscation mapping file uploading to Crashlytics."
        skip=true
    fi

    if [[ $skip == false ]]; then
        firebase crashlytics:mappingfile:upload --app=$APP_ID --resource-file=com_google_firebase_crashlytics_mappingfileid.xml mapping.txt
    fi
}