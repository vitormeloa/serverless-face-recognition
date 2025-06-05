const AWS = require('aws-sdk');
const dynamo = new AWS.DynamoDB.DocumentClient();
const s3 = new AWS.S3();

async function listTable() {
  const data = await dynamo.scan({ TableName: process.env.TABLE }).promise();
  console.log('DynamoDB Items:', JSON.stringify(data.Items, null, 2));
}

async function listObjects(prefix) {
  const data = await s3.listObjectsV2({ Bucket: process.env.BUCKET, Prefix: prefix }).promise();
  console.log('S3 Objects:', data.Contents.map(o => o.Key));
}

listTable().then(() => listObjects(process.argv[2] || 'register/')).catch(console.error);
