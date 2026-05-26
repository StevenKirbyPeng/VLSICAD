
function filterTable(inputId,tableId){const i=document.getElementById(inputId),t=document.getElementById(tableId);if(!i||!t)return;i.addEventListener('input',()=>{const q=i.value.toLowerCase();t.querySelectorAll('tbody tr').forEach(r=>r.style.display=r.textContent.toLowerCase().includes(q)?'':'none')})}
window.addEventListener('DOMContentLoaded',()=>{filterTable('hotkeySearch','hotkeyTable');filterTable('layerSearch','layerTable')});
