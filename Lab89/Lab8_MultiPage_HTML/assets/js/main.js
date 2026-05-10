document.addEventListener('DOMContentLoaded',()=>{
  document.querySelectorAll('.copy').forEach(btn=>{btn.addEventListener('click',()=>{const pre=btn.nextElementSibling; navigator.clipboard.writeText(pre.innerText); btn.textContent='已複製'; setTimeout(()=>btn.textContent='Copy',1000);});});
  document.querySelectorAll('[data-tabs]').forEach(group=>{const buttons=group.querySelectorAll('.tabbtn'); const panes=group.querySelectorAll('.tabpane'); buttons.forEach((b,i)=>b.addEventListener('click',()=>{buttons.forEach(x=>x.classList.remove('active'));panes.forEach(x=>x.classList.remove('active'));b.classList.add('active');panes[i].classList.add('active');}));});
  document.querySelectorAll('.quiz button').forEach(btn=>btn.addEventListener('click',()=>{const ok=btn.dataset.ok==='1';btn.classList.add(ok?'correct':'wrong');const msg=btn.closest('.quiz').querySelector('.qmsg'); if(msg) msg.textContent= ok?'答對：這就是正確判斷。':'再想一下：請對照真值表與 pull-up / pull-down 結構。';}));
});
