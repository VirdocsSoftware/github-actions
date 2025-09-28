const core = require('@actions/core');
const io = require('@actions/io');
const { S3Client, GetObjectCommand, PutObjectCommand, HeadObjectCommand } = require('@aws-sdk/client-s3');
const fs = require('fs');
const path = require('path');
const tar = require('tar');

async function run() {
  try {
    // Read inputs
    const cachePath = core.getInput('path');
    const cacheKey = core.getInput('key');
    const bucketName = core.getInput('s3-bucket');
    const accessKeyId = core.getInput('aws-access-key-id');
    const secretAccessKey = core.getInput('aws-secret-access-key');
    const region = core.getInput('aws-region');

    // e.g. "owner/repo"
    const repo = process.env.GITHUB_REPOSITORY;
    if (!repo) {
      throw new Error("GITHUB_REPOSITORY is not defined in the environment.");
    }

    // Build an S3 object key like: "owner/repo/cacheKey.tgz"
    const s3Key = `${repo}/${cacheKey}.tgz`;

    // Create S3 client
    const s3Client = new S3Client({
      region,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });

    // Attempt to download existing cache
    const restoreSuccess = await tryRestoreCache(s3Client, bucketName, s3Key, cachePath);

    if (restoreSuccess) {
      core.info(`Cache restored from S3: s3://${bucketName}/${s3Key}`);
    } else {
      core.info(`No cache found at s3://${bucketName}/${s3Key}`);
    }

    // Register a post-job step to upload the cache
    core.saveState('UPLOAD_CACHE', 'true');
    core.saveState('S3_KEY', s3Key);
    core.saveState('BUCKET_NAME', bucketName);
    core.saveState('REGION', region);
    core.saveState('AWS_ACCESS_KEY_ID', accessKeyId);
    core.saveState('AWS_SECRET_ACCESS_KEY', secretAccessKey);
    core.saveState('CACHE_PATH', cachePath);

  } catch (error) {
    core.setFailed(error.message);
  }
}

async function tryRestoreCache(s3Client, bucketName, s3Key, cachePath) {
  try {
    // Check if object exists
    await s3Client.send(new HeadObjectCommand({
      Bucket: bucketName,
      Key: s3Key
    }));
  } catch (err) {
    // If HeadObject fails, the object doesn't exist
    return false;
  }

  // Download the object
  const downloadPath = path.join(process.env.RUNNER_TEMP || '.', 'cache.tgz');
  const getObjectCommand = new GetObjectCommand({
    Bucket: bucketName,
    Key: s3Key,
  });

  const data = await s3Client.send(getObjectCommand);
  const writeStream = fs.createWriteStream(downloadPath);

  await new Promise((resolve, reject) => {
    data.Body.pipe(writeStream)
      .on('error', reject)
      .on('close', resolve);
  });

  // Extract to the cachePath
  await io.mkdirP(cachePath);
  await tar.extract({ file: downloadPath, cwd: cachePath, strip: 1 });
  return true;
}

run();