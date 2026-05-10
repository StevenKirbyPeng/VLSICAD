
document.addEventListener('DOMContentLoaded',()=>{
  const path=location.pathname.split('/').pop()||'index.html';
  document.querySelectorAll('.nav a').forEach(a=>{if(a.getAttribute('href')===path)a.classList.add('active')});
  document.querySelectorAll('[data-tabs]').forEach(group=>{
    const btns=group.querySelectorAll('.tabbtn'); const panes=group.querySelectorAll('.tabpane');
    btns.forEach((b,i)=>b.addEventListener('click',()=>{btns.forEach(x=>x.classList.remove('active'));panes.forEach(x=>x.classList.remove('active'));b.classList.add('active');panes[i].classList.add('active')}));
  });
  document.querySelectorAll('.checklist input').forEach((c,i)=>{
    const key='lab89_check_'+location.pathname+'_'+i; c.checked=localStorage.getItem(key)==='1';
    c.addEventListener('change',()=>localStorage.setItem(key,c.checked?'1':'0'));
  });
});
function copyCode(id){const el=document.getElementById(id); navigator.clipboard.writeText(el.innerText); alert('已複製程式碼');}
