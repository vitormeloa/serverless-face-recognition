const AWS = require('aws-sdk');
const s3 = new AWS.S3();
// Rekognition collection may live in a different region.
const rekognitionRegion = process.env.REKOGNITION_REGION || process.env.AWS_REGION;
const rekognition = new AWS.Rekognition({ region: rekognitionRegion });
const dynamo = new AWS.DynamoDB.DocumentClient();

exports.handler = async (event) => {
  const start = Date.now();
  try {
    const body = typeof event.body === 'string' ? JSON.parse(event.body) : event;
    const { imageBase64 } = body;
    if (!imageBase64) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: 'Missing imageBase64' })
      };
    }

    const buffer = Buffer.from(imageBase64, 'base64');
    const key = `recognize/${Date.now()}.jpg`;
    await s3.putObject({
      Bucket: process.env.BUCKET_NAME,
      Key: key,
      Body: buffer,
      ContentType: 'image/jpeg'
    }).promise();

    const searchResp = await rekognition.searchFacesByImage({
      CollectionId: process.env.FACE_COLLECTION_ID,
      Image: { S3Object: { Bucket: process.env.BUCKET_NAME, Key: key } },
      FaceMatchThreshold: 90
    }).promise();

    let response;
    if (searchResp.FaceMatches && searchResp.FaceMatches.length > 0) {
      const match = searchResp.FaceMatches[0];
      const faceId = match.Face.FaceId;
      const item = await dynamo.get({
        TableName: process.env.DYNAMO_TABLE_NAME,
        Key: { faceId }
      }).promise();
      response = {
        recognized: true,
        faceId,
        userId: item.Item ? item.Item.userId : null,
        confidence: match.Similarity
      };
    } else {
      response = { recognized: false, message: 'No matching face found' };
    }

    const latency = Date.now() - start;
    console.log(`Latency: ${latency}ms, Matched: ${response.recognized}`);

    return {
      statusCode: 200,
      body: JSON.stringify(response)
    };
  } catch (err) {
    console.error(err);
    return {
      statusCode: 500,
      body: JSON.stringify({ message: 'Internal server error' })
    };
  }
};
