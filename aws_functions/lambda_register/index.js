const AWS = require('aws-sdk');
const s3 = new AWS.S3();
// Rekognition may run in a different region than the Lambda itself.
const rekognitionRegion = process.env.REKOGNITION_REGION || process.env.AWS_REGION;
const rekognition = new AWS.Rekognition({ region: rekognitionRegion });
const dynamo = new AWS.DynamoDB.DocumentClient();
const sns = new AWS.SNS();

exports.handler = async (event) => {
  try {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event;
    const { userId, imageBase64 } = body;
    if (!userId || !imageBase64) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Missing userId or imageBase64' })
      };
    }

    const imageBuffer = Buffer.from(imageBase64, 'base64');
    const timestamp   = Date.now();
    const key         = `register/${userId}/${timestamp}.jpg`;

    // 1) Grava no S3 para persistência
    await s3.putObject({
      Bucket      : process.env.BUCKET_NAME,
      Key         : key,
      Body        : imageBuffer,
      ContentType : 'image/jpeg'
    }).promise();

    // 2) Indexa no Rekognition a partir do objeto S3
    const indexResp = await rekognition.indexFaces({
      CollectionId     : process.env.FACE_COLLECTION_ID,
      Image            : { S3Object: { Bucket: process.env.BUCKET_NAME, Name: key } },
      ExternalImageId  : userId
    }).promise();

    const faceRecord = indexResp.FaceRecords && indexResp.FaceRecords[0];
    if (!faceRecord) {
      return {
        statusCode: 400,
        body      : JSON.stringify({ message: 'No face detected in image' })
      };
    }

    const faceId = faceRecord.Face.FaceId;

    // 3) Salva metadados no Dynamo
    await dynamo.put({
      TableName : process.env.DYNAMO_TABLE_NAME,
      Item      : { faceId, userId, s3ObjectKey: key, timestamp }
    }).promise();

    // 4) Notifica via SNS
    await sns.publish({
      TopicArn : process.env.SNS_TOPIC_ARN,
      Message  : `New face registered: ${faceId} for userId: ${userId}`
    }).promise();

    return {
      statusCode: 200,
      body      : JSON.stringify({ faceId, message: 'Face registered successfully' })
    };
  } catch (err) {
    console.error(err);
    return {
      statusCode: 500,
      body      : JSON.stringify({ message: 'Internal server error' })
    };
  }
};