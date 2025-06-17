# Primary region for most resources. Change to match your AWS configuration
region           = "us-east-1"
# Rekognition must run in a supported region
rekognition_region = "us-east-1"
face_collection_id = "FaceCollection"
dynamo_table_name  = "FaceMetadataTable"
sns_topic_name     = "FaceRegistrationTopic"
bucket_name        = "face-images-bucket"
