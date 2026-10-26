// Offline node annotations. User text is always rendered as text, never HTML.
const annotationKey='orca-player.node-annotations.v1';
let annotations={};
const annotationStatus=elem('p','','muted');annotationStatus.setAttribute('role','status');
try{const saved=JSON.parse(localStorage.getItem(annotationKey)||'{}');annotations=validateAnnotations(saved)}catch{annotationStatus.textContent='無法讀取本機註解；請匯入備份或使用匯出保留本次內容。'}
function validateAnnotations(value){
 if(!value||typeof value!=='object'||Array.isArray(value))throw Error('格式錯誤');
 const result={};for(const [id,items] of Object.entries(value)){
  if(!byId.has(id)||!Array.isArray(items)||items.length>500)throw Error('節點或註解數量不符');
  result[id]=items.map(c=>{if(!c||typeof c.text!=='string'||c.text.length>10000||typeof c.id!=='string'||typeof c.date!=='string'||typeof c.resolved!=='boolean')throw Error('註解格式錯誤');return {id:c.id,text:c.text,date:c.date,resolved:c.resolved}});
 }return result;
}
function persistAnnotations(){
 try{localStorage.setItem(annotationKey,JSON.stringify(annotations));annotationStatus.textContent='已儲存在此瀏覽器；交辦前請匯出註解 JSON。'}catch{annotationStatus.textContent='瀏覽器儲存失敗；請立即匯出 JSON 備份。'}
 updateAnnotationBadges();
}
function updateAnnotationBadges(){for(const [id,b] of buttons){let badge=b.querySelector('.annotation-badge');if(!badge){badge=elem('small','','annotation-badge');b.append(badge)}const items=annotations[id]||[];badge.textContent=items.length?'💬 '+items.filter(c=>!c.resolved).length+' 待處理 / '+items.length+' 則':''}requestAnimationFrame(draw)}
function annotationPanel(id){
 const section=elem('section');section.id='node-comments';section.append(elem('h3','節點註解／修改需求'),elem('p','輸入會自動保留草稿。註解不會直接修改程式或任務狀態。','muted'));
 const list=elem('div');section.append(list);
 function render(){list.replaceChildren();for(const c of annotations[id]||[]){const card=elem('article',undefined,'annotation-card');card.append(elem('small',c.date+(c.resolved?' · 已解決':' · 待處理'),'muted'));const input=elem('textarea');input.value=c.text;input.maxLength=10000;input.rows=4;input.setAttribute('aria-label',id+' 註解內容');input.addEventListener('input',()=>{c.text=input.value;persistAnnotations()});const toggle=elem('button',c.resolved?'重新開啟':'標記已解決','dep');toggle.onclick=()=>{c.resolved=!c.resolved;persistAnnotations();render()};card.append(input,toggle);list.append(card)}}
 const add=elem('button','＋ 新增註解','dep');add.onclick=()=>{(annotations[id]??=[]).push({id:crypto.randomUUID(),text:'',date:new Date().toISOString(),resolved:false});persistAnnotations();render();list.lastElementChild.querySelector('textarea').focus()};section.append(add);render();return section;
}
const originalSelect=select;
select=function(id,options={}){originalSelect(id,options);if(id){const panel=annotationPanel(id);inspector.insertBefore(panel,inspector.children[4]||null)}};
const tools=elem('div',undefined,'toolbar');
function tool(text,action){const b=elem('button',text);b.type='button';b.onclick=action;tools.append(b);return b}
let diagramZoom=1;
const zoomLabel=elem('span','100%');
function setDiagramZoom(value){diagramZoom=Math.max(.3,Math.min(1.75,value));board.style.zoom=diagramZoom;zoomLabel.textContent=Math.round(diagramZoom*100)+'%';requestAnimationFrame(draw)}
tool('縮小 −',()=>setDiagramZoom(diagramZoom-.1));tools.append(zoomLabel);tool('放大 ＋',()=>setDiagramZoom(diagramZoom+.1));tool('100%',()=>setDiagramZoom(1));tool('符合寬度',()=>setDiagramZoom(document.querySelector('.board-scroll').clientWidth/1902));
tool('匯出註解 JSON',()=>{const data=JSON.stringify({schema_version:1,project:'music-player',annotations},null,2);const url=URL.createObjectURL(new Blob([data],{type:'application/json'}));const a=elem('a');a.href=url;a.download='music-player-node-comments-'+new Date().toISOString().slice(0,10)+'.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)});
const importFile=elem('input');importFile.type='file';importFile.accept='.json,application/json';importFile.hidden=true;tools.append(importFile);tool('匯入註解 JSON',()=>importFile.click());
importFile.onchange=async()=>{try{const file=importFile.files[0];if(!file)return;if(file.size>5000000)throw Error('檔案超過 5 MB');const payload=JSON.parse(await file.text());if(payload.schema_version!==1||!['music-player','orca-player'].includes(payload.project))throw Error('專案或版本不符');const incoming=validateAnnotations(payload.annotations);for(const [id,items] of Object.entries(incoming)){const existing=annotations[id]??=[];for(const item of items){const prior=existing.find(c=>c.id===item.id);if(!prior)existing.push(item);else if(prior.text!==item.text||prior.resolved!==item.resolved)existing.push({...item,id:crypto.randomUUID()})}}persistAnnotations();if(selected)select(selected,{updateHash:false});annotationStatus.textContent='已合併匯入；衝突內容另存一則，原註解保留。'}catch(error){annotationStatus.textContent='未匯入：'+error.message}finally{importFile.value=''}};
const viewport=document.querySelector('.board-scroll');viewport.before(tools,annotationStatus);updateAnnotationBadges();if(selected)select(selected,{updateHash:false});
// Rectangles reflect zoom, SVG coordinates must remain unscaled.
