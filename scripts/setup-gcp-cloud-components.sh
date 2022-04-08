#!/usr/bin/env sh

CLOUD_COMPONENTS_FILE=".default-cloud-sdk-components"
LOCATION="$HOME/.config/gcloud"

if [ -f "$LOCATION/$CLOUD_COMPONENTS_FILE" ]; then
echo "####################
# It appears $LOCATION/$CLOUD_COMPONENTS_FILE already exists
# Please ensure you create a backup if required

#   % cp \"$LOCATION/$CLOUD_COMPONENTS_FILE\" \"$LOCATION/$CLOUD_COMPONENTS_FILE.bkp\"

# Old $LOCATION/$CLOUD_COMPONENTS_FILE contents:

<< FILE_CONTENT
$(cat $LOCATION/$CLOUD_COMPONENTS_FILE)

FILE_CONTENT
####################"

    sort $(cat $LOCATION/$CLOUD_COMPONENTS_FILE 2>/dev/null) $CLOUD_COMPONENTS_FILE | uniq
    echo "> Merged $LOCATION/$CLOUD_COMPONENTS_FILE"

    exit 0
fi

# Copy the files across
cp $CLOUD_COMPONENTS_FILE $LOCATION/$CLOUD_COMPONENTS_FILE
echo "> Copied $LOCATION/$CLOUD_COMPONENTS_FILE"

exit 0
