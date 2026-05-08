
function qs(sel, root=document){ return root.querySelector(sel); }
function qsa(sel, root=document){ return Array.from(root.querySelectorAll(sel)); }

function setupImageModal(){
  const modal = qs('#imgModal');
  if(!modal) return;
  qsa('[data-fullimg]').forEach(el=>{
    el.addEventListener('click', ()=>{
      const img = qs('#imgModalImage');
      const cap = qs('#imgModalCaption');
      img.src = el.getAttribute('data-fullimg');
      cap.textContent = el.getAttribute('data-caption') || '';
      modal.classList.add('open');
    });
  });
  modal.addEventListener('click', e=>{
    if(e.target === modal || e.target.classList.contains('closeModal')) modal.classList.remove('open');
  });
}
function setupTabs(){
  qsa('[data-tabs]').forEach(group=>{
    const btns = qsa('[data-tabbtn]', group);
    const panes = qsa('[data-tabpane]', group);
    btns.forEach(btn=>{
      btn.addEventListener('click', ()=>{
        const target = btn.getAttribute('data-tabbtn');
        btns.forEach(b=>b.classList.remove('active'));
        panes.forEach(p=>p.classList.remove('active'));
        btn.classList.add('active');
        qs(`[data-tabpane="${target}"]`, group).classList.add('active');
      });
    });
  });
}
function setupSearchTable(){
  const input = qs('#lineSearch');
  if(!input) return;
  input.addEventListener('input', ()=>{
    const q = input.value.trim().toLowerCase();
    qsa('tbody tr[data-search]').forEach(tr=>{
      tr.style.display = tr.getAttribute('data-search').includes(q) ? '' : 'none';
    });
  });
}
function setupCardSearch(){
  const input = qs('#cardSearch');
  if(!input) return;
  input.addEventListener('input', ()=>{
    const q = input.value.trim().toLowerCase();
    qsa('.searchCard').forEach(card=>{
      card.style.display = card.innerText.toLowerCase().includes(q) ? '' : 'none';
    });
  });
}
function setupExpandButtons(){
  const openBtn = qs('#openAll');
  const closeBtn = qs('#closeAll');
  if(openBtn) openBtn.onclick = ()=> qsa('details').forEach(d=>d.open = true);
  if(closeBtn) closeBtn.onclick = ()=> qsa('details').forEach(d=>d.open = false);
}
document.addEventListener('DOMContentLoaded', ()=>{
  setupImageModal();
  setupTabs();
  setupSearchTable();
  setupCardSearch();
  setupExpandButtons();
});
