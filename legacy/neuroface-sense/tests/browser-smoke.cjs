const {chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path');
(async()=>{
  const chrome=process.env.CHROME_PATH||'C:/Program Files/Google/Chrome/Application/chrome.exe';
  const browser=await chromium.launch({...(fs.existsSync(chrome)?{executablePath:chrome}:{}),headless:true,args:['--use-fake-ui-for-media-stream','--use-fake-device-for-media-stream']});
  const context=await browser.newContext({viewport:{width:1440,height:1000},permissions:['camera']}),page=await context.newPage(),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  // Verify that the locally bundled application/runtime can run with external URLs blocked.
  await context.route(/^https?:\/\/(?!127\.0\.0\.1:4173)/,route=>route.abort());
  await page.goto('http://127.0.0.1:4173');await page.waitForFunction(()=>document.querySelector('#logList').textContent.includes('ready'));
  await page.getByRole('button',{name:'isolated synthetic blink test',exact:false}).click();
  assert.match(await page.locator('#logList').innerText(),/replay: 1 event/);
  await page.getByRole('button',{name:'Demo Mode',exact:true}).click();await page.waitForFunction(()=>document.querySelector('#vFace').textContent.startsWith('yes'));
  const screenshot=process.env.NF_QA_SCREENSHOT||path.join(__dirname,'../test-results/dashboard.png');
  fs.mkdirSync(path.dirname(screenshot),{recursive:true});await page.screenshot({path:screenshot,fullPage:true});
  await page.getByRole('button',{name:'Calibrate Patient',exact:false}).click();await page.getByRole('button',{name:'Capture step',exact:true}).click();
  assert.match(await page.locator('#logList').innerText(),/real live tracked face/);await page.getByRole('button',{name:'Close',exact:true}).click();
  await page.locator('#devPanel summary').click();assert.equal(await page.locator('#detectorConfig').isVisible(),true);
  const db=await page.evaluate(async()=>{
    const b=NF_engine.baseline();await NF_storage.saveCalibration({validated:true,originalCalibration:b,adaptiveCalibration:b,savedAt:new Date().toISOString(),stages:{neutral:{stats:{earMean:{median:.27}}}}});
    const saved=await NF_storage.loadCalibration();const r=new NF_storage.Recorder(e=>{throw e;});const e=new NF_engine.Engine();await r.start(e,'synthetic-test');const id=r.session.id;
    const f={timestamp:100,facePresent:false,faceQuality:0};r.record(f,e.process(f),e);await r.stop();clearInterval(r.timer);
    const data=await NF_storage.exportSession(id);return {saved:!!saved.validated,frames:data.frameFeatures.length,id};
  });assert.equal(db.saved,true);assert.equal(db.frames,1);
  await page.reload();await page.waitForFunction(()=>document.querySelector('#twinStatus').textContent.includes('validated'));
  await page.locator('#devPanel summary').click();await page.locator('#sessionRefresh').click();await page.waitForFunction(()=>document.querySelector('#sessionSelect').options.length===1);
  await page.locator('#sessionReplay').click();await page.waitForFunction(()=>document.querySelector('#devStatus').textContent.includes('Replay:'));
  // Load actual bundled runtime and run inference on an empty canvas, without a real camera.
  const model=await page.evaluate(async()=>{const m=await NF_vision.create();const canvas=document.createElement('canvas');canvas.width=640;canvas.height=480;canvas.getContext('2d').fillRect(0,0,640,480);const r=m.detectForVideo(canvas,performance.now());m.close();return {faces:r.faceLandmarks.length};});
  assert.equal(model.faces,0);
  await page.getByRole('button',{name:'Start Camera',exact:false}).click();await page.waitForFunction(()=>document.querySelector('#pdSent').textContent!=='0',{timeout:30000});
  assert.match(await page.locator('#camStatus').innerText(),/live/);
  await page.locator('#btnCamera').click();
  // Exercise accepted-frame integration using explicitly synthetic numeric features.
  await page.reload();await page.waitForFunction(()=>document.querySelector('#twinStatus').textContent.includes('validated'));
  await page.locator('#devPanel summary').click();
  await page.evaluate(()=>{
    let start;
    navigator.mediaDevices.getUserMedia=async()=>{const c=document.createElement('canvas');c.width=640;c.height=480;const x=c.getContext('2d');let n=0;setInterval(()=>{x.fillStyle=n++%2?'#777':'#888';x.fillRect(0,0,640,480);},33);return c.captureStream(30);};
    const landmarks=Array.from({length:478},(_,i)=>({x:.5+Math.cos(i/478*Math.PI*2)*.16,y:.5+Math.sin(i/478*Math.PI*2)*.23,z:0}));
    NF_vision.create=async()=>({detectForVideo:()=>({faceLandmarks:[landmarks]})});
    NF_vision.Extractor=class{extract(_r,_v,t){if(start===undefined)start=t;const elapsed=t-start,phase=elapsed-1000;
      const blink=phase>=0&&phase<2400&&phase%800<330;
      const turns=elapsed-3800,yaw=turns>=0&&turns<3600&&turns%1200<500?-24:0;
      return {timestamp:t,facePresent:true,poseValid:true,blendshapesValid:true,faceQuality:1,trackingConfidence:null,confidenceSource:'synthetic integration fixture',earLeft:blink?.07:.27,earRight:blink?.07:.27,earMean:blink?.07:.27,eyeBlinkLeft:blink?.95:0,eyeBlinkRight:blink?.95:0,mouthSmileLeft:.02,mouthSmileRight:.02,cheekSquintLeft:0,cheekSquintRight:0,mouthClose:1,jawOpen:0,mouthPucker:0,mouthCornerLeftX:.2,mouthCornerLeftY:0,mouthCornerRightX:-.2,mouthCornerRightY:0,yaw,pitch:0,roll:0,faceSize:.4,centerX:.5,centerY:.5,inFrame:true,brightness:120,fps:30,poseSpeed:0,mouthWidth:.15,browGap:.05,lipDeviation:0,cornerDepression:0,mar:0,gaze:{x:0,y:0,available:true}};
    }};
  });
  await page.locator('#btnCamera').click();
  await page.waitForFunction(()=>document.querySelector('#pdSent').textContent!=='0');
  await page.locator('#recordStart').click();
  await page.waitForFunction(()=>document.querySelector('#devStatus').textContent.includes('Recording selected'));
  try{await page.waitForFunction(()=>document.querySelector('#cmdDisplay').textContent==='I need water',null,{timeout:12000});}catch(e){console.log(await page.locator('#logList').innerText(),await page.locator('#pdErrMsg').innerText(),await page.locator('#devReadout').innerText(),await page.locator('#devStatus').innerText(),errors);throw e;}
  await page.waitForFunction(()=>document.querySelector('#cmdDisplay').textContent==='I need food',null,{timeout:12000});
  assert.equal(await page.locator('#pdErr').innerText(),'0');
  await page.locator('#recordStop').click();await page.locator('#sessionRefresh').click();await page.waitForFunction(()=>document.querySelector('#sessionSelect').options.length>=2);
  await page.locator('#sessionReplay').click();await page.waitForFunction(()=>document.querySelector('#devStatus').textContent.includes('2 commands'));
  await page.locator('#btnCamera').click();
  assert.deepEqual(errors,[]);console.log(JSON.stringify({browser:'Chrome',domErrors:errors,storage:db,actualModel:model,checks:['dashboard','demo','isolated blink','real-camera calibration guard','diagnostics','IndexedDB save/reload','numeric replay','bundled inference','fake camera start/stop','accepted-frame triple blink → water','accepted-frame three left returns → food','full-rate session replay → same two commands','external network blocked']},null,2));
  await browser.close();
})().catch(e=>{console.error(e);process.exit(1);});
