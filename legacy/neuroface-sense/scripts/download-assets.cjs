/* Download only vendor runtime/model binaries, never user data. */
const fs=require('node:fs/promises'),path=require('node:path'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),version='0.10.22-rc.20250304';
const cdn='https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@'+version;
const files=[['vendor/vision_bundle.mjs',cdn+'/vision_bundle.mjs'],
  ['vendor/tf.min.js','https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.17.0/dist/tf.min.js'],
  ...['vision_wasm_internal.js','vision_wasm_internal.wasm','vision_wasm_nosimd_internal.js','vision_wasm_nosimd_internal.wasm'].map(x=>['vendor/wasm/'+x,cdn+'/wasm/'+x]),
  ['models/face_landmarker.task','https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task'],
  ['models/hand_landmarker.task','https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task'],
  ['vendor/MEDIAPIPE-LICENSE.txt','https://raw.githubusercontent.com/google-ai-edge/mediapipe/master/LICENSE'],
  ['vendor/TFJS-LICENSE.txt','https://raw.githubusercontent.com/tensorflow/tfjs/master/LICENSE']];
(async()=>{const manifest=[];for(const [relative,url] of files){const response=await fetch(url);if(!response.ok)throw Error(url+': '+response.status);const bytes=Buffer.from(await response.arrayBuffer());const target=path.join(root,relative);await fs.mkdir(path.dirname(target),{recursive:true});await fs.writeFile(target,bytes);manifest.push({path:relative,url,bytes:bytes.length,sha256:crypto.createHash('sha256').update(bytes).digest('hex')});console.log(relative,bytes.length);}
  await fs.writeFile(path.join(root,'vendor/manifest.json'),JSON.stringify({version,downloadedAt:new Date().toISOString(),files:manifest},null,2));
})().catch(e=>{console.error(e.message);process.exitCode=1;});
