const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const context={window:{},console,URL};vm.createContext(context);vm.runInContext(fs.readFileSync(require.resolve('../src/vision.js'),'utf8'),context);
const pose=context.window.NF_vision.headPose;
test('matrix pose is scale-independent and uses column-major coordinates',()=>{const a=20*Math.PI/180,c=Math.cos(a),s=Math.sin(a),p=pose({rows:4,columns:4,data:[2*c,0,-2*s,0,0,2,0,0,2*s,0,2*c,0,2,3,-50,1]});assert.ok(Math.abs(p.yaw+20)<1e-6);assert.equal(p.pitch,0);assert.equal(p.roll,0);});
test('matrix pitch and roll decompose correctly',()=>{const a=15*Math.PI/180,c=Math.cos(a),s=Math.sin(a);const p=pose({rows:4,columns:4,data:[1,0,0,0,0,c,s,0,0,-s,c,0,0,0,-50,1]});assert.ok(Math.abs(p.pitch-15)<1e-6);const r=pose({rows:4,columns:4,data:[c,s,0,0,-s,c,0,0,0,0,1,0,0,0,-50,1]});assert.ok(Math.abs(r.roll-15)<1e-6);});
test('missing, malformed and degenerate matrices rejected',()=>{assert.equal(pose(null),null);assert.equal(pose({rows:4,columns:4,data:Array(16).fill(0)}),null);assert.equal(pose({rows:4,columns:4,data:Array(16).fill(NaN)}),null);});
