
function showTab(group, id){
  document.querySelectorAll('[data-tab-group="'+group+'"]').forEach(x=>x.classList.remove('active'));
  document.querySelectorAll('[data-tab-btn="'+group+'"]').forEach(x=>x.classList.remove('active'));
  document.getElementById(id).classList.add('active');
  document.querySelector('[data-target="'+id+'"]').classList.add('active');
}
function copyCode(id){
  const t=document.getElementById(id).innerText;
  navigator.clipboard.writeText(t);
  const b=document.querySelector('[data-copy="'+id+'"]');
  const old=b.innerText; b.innerText='已複製'; setTimeout(()=>b.innerText=old,900);
}
function quiz(btn, ok){
  const r=btn.parentElement.querySelector('.result');
  if(ok){r.textContent='✅ 正確'; r.className='result ok'} else {r.textContent='❌ 再想想：注意 PUN/PDN 的串並聯關係或流程順序。'; r.className='result bad'}
}
