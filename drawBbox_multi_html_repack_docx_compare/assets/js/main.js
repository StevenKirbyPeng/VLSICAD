
function filterCards(){
  const q = document.getElementById('q')?.value.toLowerCase() || '';
  document.querySelectorAll('.step-card').forEach(card=>{
    card.style.display = card.innerText.toLowerCase().includes(q) ? '' : 'none';
  });
}
function copyCode(id){
  const el = document.getElementById(id);
  if(!el) return;
  navigator.clipboard.writeText(el.innerText);
  const btn = document.querySelector(`[data-copy="${id}"]`);
  if(btn){ const old=btn.innerText; btn.innerText='已複製'; setTimeout(()=>btn.innerText=old,900); }
}
function toggleAll(open){
  document.querySelectorAll('details.code-detail').forEach(d=>d.open=open);
}
