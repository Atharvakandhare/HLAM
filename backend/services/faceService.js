const tf = require('@tensorflow/tfjs');
const faceapi = require('@vladmandic/face-api');
const canvas = require('@napi-rs/canvas');
const path = require('path');
const fs = require('fs');

// Patch face-api environment to use node-canvas
const { Canvas, Image, ImageData } = canvas;
faceapi.env.monkeyPatch({ Canvas, Image, ImageData });

let modelsLoaded = false;

const loadFaceModels = async () => {
  if (modelsLoaded) return;
  
  const weightsPath = path.join(__dirname, '../weights');
  
  // Ensure the weights directory exists
  if (!fs.existsSync(weightsPath)) {
    fs.mkdirSync(weightsPath, { recursive: true });
    throw new Error(`Face-api models directory not found. Created folder at '${weightsPath}'. Please place model weight files there.`);
  }

  // Check if standard model weights are present before loading
  const requiredFiles = [
    'ssd_mobilenetv1_model-weights_manifest.json',
    'face_landmark_68_model-weights_manifest.json',
    'face_recognition_model-weights_manifest.json'
  ];
  const missingFiles = requiredFiles.filter(file => !fs.existsSync(path.join(weightsPath, file)));
  
  if (missingFiles.length > 0) {
    throw new Error(`Missing face-api weight files in '${weightsPath}': ${missingFiles.join(', ')}`);
  }

  try {
    await faceapi.nets.ssdMobilenetv1.loadFromDisk(weightsPath);
    await faceapi.nets.faceLandmark68Net.loadFromDisk(weightsPath);
    await faceapi.nets.faceRecognitionNet.loadFromDisk(weightsPath);
    modelsLoaded = true;
    console.log('[FaceService] Models loaded successfully.');
  } catch (error) {
    console.error('[FaceService] Failed to load models:', error.message);
    throw error;
  }
};

/**
 * Extracts a 128-float face descriptor array from an image path.
 * Returns null if no face is detected or if processing fails.
 */
const getFaceDescriptor = async (imagePath) => {
  try {
    await loadFaceModels();
    
    if (!fs.existsSync(imagePath)) {
      throw new Error(`Image file not found: ${imagePath}`);
    }

    const img = await canvas.loadImage(imagePath);
    const detection = await faceapi.detectSingleFace(img)
      .withFaceLandmarks()
      .withFaceDescriptor();

    if (!detection) {
      console.log(`[FaceService] No face detected in image: ${imagePath}`);
      return null;
    }

    // Convert Float32Array to standard JavaScript array for serialization
    return Array.from(detection.descriptor);
  } catch (error) {
    console.error(`[FaceService] Error getting descriptor for ${imagePath}:`, error.message);
    // Don't crash, return null to indicate failure
    return null;
  }
};

/**
 * Calculates Euclidean distance between two descriptors and returns matching result.
 */
const verifyFaceMatch = (descriptor1, descriptor2, threshold = 0.6) => {
  if (!descriptor1 || !descriptor2) {
    return { isMatch: false, distance: 1.0, error: 'Missing descriptors' };
  }

  const d1 = Array.isArray(descriptor1) ? descriptor1 : Array.from(descriptor1);
  const d2 = Array.isArray(descriptor2) ? descriptor2 : Array.from(descriptor2);

  if (d1.length !== 128 || d2.length !== 128) {
    return { isMatch: false, distance: 1.0, error: 'Invalid descriptor length' };
  }

  let sum = 0;
  for (let i = 0; i < 128; i++) {
    const diff = d1[i] - d2[i];
    sum += diff * diff;
  }
  const distance = Math.sqrt(sum);

  return {
    isMatch: distance <= threshold,
    distance
  };
};

module.exports = {
  loadFaceModels,
  getFaceDescriptor,
  verifyFaceMatch
};
