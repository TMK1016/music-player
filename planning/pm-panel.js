const pmPlan=JSON.parse(document.getElementById('pm-data').textContent);
const pmPanel=elem('details');pmPanel.id='pm-overview';pmPanel.open=true;pmPanel.className='journal-detail';
pmPanel.append(elem('summary','Music Player · PM 專案流程與工作排序'));
pmPanel.append(elem('p',pmPlan.stages.map(s=>s.name).join(' → ')),elem('p',pmPlan.method,'muted'));
for(const stage of pmPlan.stages)pmPanel.append(elem('p',stage.name+'：'+stage.exit,'muted'));
for(const [path,label] of [['docs/product/PRD-music-player.md','產品需求基準'],['docs/product/PM流程與驗收.md','成果路線與驗收情境']])pmPanel.append(fileLink(path,label));
for(const item of pmPlan.items){const card=elem('details',undefined,'annotation-card');card.append(elem('summary',item.id+' · '+item.horizon+' · '+item.title+' · '+item.status));card.append(elem('p',item.story),elem('p','排序理由：'+item.reason),elem('p','取捨：'+item.tradeoff,'muted'));const checks=elem('ul');for(const check of item.acceptance)checks.append(elem('li',check));card.append(checks,elem('p','相依：'+(item.depends_on.join('、')||'無'),'muted'));for(const id of item.node_ids){const b=elem('button',id+' · '+byId.get(id).title,'dep');b.onclick=()=>select(id,{reveal:true});card.append(b)}pmPanel.append(card)}
pmPanel.append(elem('p','PM 狀態與工程節點以 ID 對應；候選規劃不代表已授權實作或驗收通過。','warning'));
document.querySelector('main').prepend(pmPanel);
