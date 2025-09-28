const core = require('@actions/core');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');
const path = require('path');
const tar = require('tar');

async function run() {
  try {
    // Check if we should upload
    const shouldUpload = core.getState('UPLOAD_CACHE');
    if (!shouldUpload) {
      core.info("No cache upload step triggered.");
      return;
    }

    // Retrieve data from state
    const s3Key = core.getState('S3_KEY');
    const bucketName = core.getState('BUCKET_NAME');
    const region = core.getState('REGION');
    const accessKeyId = core.getState('AWS_ACCESS_KEY_ID');
    const secretAccessKey = core.getState('AWS_SECRET_ACCESS_KEY');
    const cachePath = core.getState('CACHE_PATH');

    // Tar the cachePath
    const archivePath = path.join(process.env.RUNNER_TEMP || '.', 'upload-cache.tgz');
    await tar.create({
      gzip: true,
      file: archivePath,
      cwd: cachePath
    }, ['.']); // Tar the entire contents of cachePath

    // Create S3 client
    const s3Client = new S3Client({
      region,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });

    // Upload
    const fileStream = fs.createReadStream(archivePath);
    await s3Client.send(new PutObjectCommand({
      Bucket: bucketName,
      Key: s3Key,
      Body: fileStream
    }));

    core.info(`Cache uploaded to s3://${bucketName}/${s3Key}`);
  } catch (error) {
    // Don’t fail the build if cache upload fails; just log it
    core.warning(`Failed to upload cache: ${error.message}`);
  }
}

run();