const {Storage} = require('@google-cloud/storage');
const vision = require('@google-cloud/vision');
const {PubSub} = require('@google-cloud/pubsub');
const {Firestore} = require('@google-cloud/firestore');
const {v4: uuidv4} = require('uuid');

const storage = new Storage();
const client = new vision.ImageAnnotatorClient();
const pubsub = new PubSub();
const firestore = new Firestore();

/**
 * registerFace Cloud Function
 * - expects JSON { userId, imageBase64 }
 */
exports.registerFace = async (req, res) => {
  try {
    const {userId, imageBase64} = req.body || {};
    if (!userId || !imageBase64) {
      res.status(400).json({message: 'Missing userId or imageBase64'});
      return;
    }

    const buffer = Buffer.from(imageBase64, 'base64');
    const faceId = uuidv4();
    const filePath = `register/${userId}/${faceId}.jpg`;
    const bucket = storage.bucket(process.env.BUCKET_NAME);
    await bucket.file(filePath).save(buffer, {contentType: 'image/jpeg'});

    // Verify face exists using Vision API
    const [result] = await client.faceDetection({image: {content: buffer}});
    if (!result.faceAnnotations || result.faceAnnotations.length === 0) {
      res.status(400).json({message: 'No face detected in image'});
      return;
    }

    // Write Firestore record
    const doc = firestore.collection('face_metadata').doc(faceId);
    const timestamp = Date.now();
    await doc.set({
      faceId,
      userId,
      faceImageUri: `gs://${process.env.BUCKET_NAME}/${filePath}`,
      timestamp
    });

    // Publish Pub/Sub message
    const dataBuffer = Buffer.from(JSON.stringify({faceId, userId, timestamp}));
    await pubsub.topic(process.env.PUBSUB_TOPIC).publish(dataBuffer);

    res.status(200).json({faceId, message: 'Face registered successfully'});
  } catch (err) {
    console.error(err);
    res.status(500).json({message: 'Internal server error'});
  }
};
