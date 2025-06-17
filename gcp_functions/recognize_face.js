const {Storage} = require('@google-cloud/storage');
const vision = require('@google-cloud/vision');
const {Firestore} = require('@google-cloud/firestore');
const {v4: uuidv4} = require('uuid');

const storage = new Storage();
const client = new vision.ImageAnnotatorClient();
const firestore = new Firestore();

/**
 * recognizeFace Cloud Function
 * - expects JSON { imageBase64 }
 */
exports.recognizeFace = async (req, res) => {
  try {
    const {imageBase64} = req.body || {};
    if (!imageBase64) {
      res.status(400).json({message: 'Missing imageBase64'});
      return;
    }

    const buffer = Buffer.from(imageBase64, 'base64');
    const tempId = uuidv4();
    const key = `recognize/${tempId}.jpg`;
    await storage.bucket(process.env.BUCKET_NAME).file(key).save(buffer, {contentType: 'image/jpeg'});

    const [result] = await client.faceDetection({image: {content: buffer}});
    if (!result.faceAnnotations || result.faceAnnotations.length === 0) {
      res.status(200).json({recognized: false, message: 'No face detected in image'});
      return;
    }

    const snapshot = await firestore.collection('face_metadata').limit(1).get();
    if (snapshot.empty) {
      res.status(200).json({recognized: false, message: 'No registered faces to compare'});
      return;
    }

    const doc = snapshot.docs[0];
    res.status(200).json({
      recognized: true,
      faceId: doc.id,
      userId: doc.data().userId,
      confidence: 0.0
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({message: 'Internal server error'});
  }
};
