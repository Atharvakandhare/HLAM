/**
 * Post-install script to create the @tensorflow/tfjs-node mock.
 * This is needed because @vladmandic/face-api requires tfjs-node
 * but the native C++ bindings fail to compile on Windows without
 * Visual Studio build tools. This mock redirects to the pure JS version.
 */
const fs = require('fs');
const path = require('path');

const mockDir = path.join(__dirname, 'node_modules', '@tensorflow', 'tfjs-node');

if (!fs.existsSync(mockDir)) {
    fs.mkdirSync(mockDir, { recursive: true });
}

fs.writeFileSync(
    path.join(mockDir, 'index.js'),
    "module.exports = require('@tensorflow/tfjs');\n"
);

fs.writeFileSync(
    path.join(mockDir, 'package.json'),
    JSON.stringify({ name: '@tensorflow/tfjs-node', version: '4.22.0', main: 'index.js' }, null, 2) + '\n'
);

console.log('[postinstall] @tensorflow/tfjs-node mock created successfully.');
