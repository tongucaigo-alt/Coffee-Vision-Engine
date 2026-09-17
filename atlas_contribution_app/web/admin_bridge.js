window.atlasCaptcha = () => new Promise((resolve, reject) => {
  const panel = document.createElement('div');
  Object.assign(panel.style, {position:'fixed', inset:'0', background:'#ffffff', zIndex:'100000', display:'grid', placeContent:'center'});
  const frame = document.createElement('iframe'); frame.src = 'captcha.html'; frame.title = 'Güvenli giriş';
  Object.assign(frame.style, {width:'min(94vw,440px)',height:'400px',border:'0'});
  const cancel = document.createElement('button'); cancel.textContent='Vazgeç'; cancel.style.minHeight='48px';
  const finish = () => {clearTimeout(timeout);window.removeEventListener('message',receive);panel.remove();};
  const receive = event => {
    if(event.origin!==location.origin || event.source!==frame.contentWindow || typeof event.data?.atlasCaptchaToken!=='string') return;
    const token=event.data.atlasCaptchaToken;finish();resolve(token);
  };
  cancel.onclick=()=>{finish();reject(Error('cancelled'));};
  const timeout=setTimeout(()=>{finish();reject(Error('timeout'));},180000);
  window.addEventListener('message',receive);panel.append(frame,cancel);document.body.append(panel);
});
window.atlasDownload = (text, name) => {
  const url=URL.createObjectURL(new Blob([text],{type:'application/json'}));
  const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
};
