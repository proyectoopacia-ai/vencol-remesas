// Botones para compartir la pieza del día por WhatsApp.
// La imagen se prepara al abrir la página porque el celular solo permite compartir justo después del toque.
const HTML2CANVAS = 'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js';
const exportando = new URLSearchParams(location.search).has('export');
let imagen = null;

function cargarLibreria() {
  return new Promise((listo, fallo) => {
    const s = document.createElement('script');
    s.src = HTML2CANVAS;
    s.onload = listo;
    s.onerror = fallo;
    document.head.append(s);
  });
}

async function prepararImagen(nombre) {
  await cargarLibreria();
  await document.fonts.ready;
  const lienzo = await html2canvas(document.querySelector('main'), {
    scale: 1, width: 1080, height: 1920, windowWidth: 1080, windowHeight: 1920, scrollX: 0, scrollY: 0,
    backgroundColor: '#04101f', useCORS: true, logging: false,
    // La copia se dibuja a tamaño real; la página visible conserva su ajuste
    onclone: copia => {
      copia.documentElement.style.zoom = 1;
      // html2canvas separa las letras con espaciado negativo y aclara las sombras internas
      const ajustes = copia.createElement('style');
      ajustes.textContent = '.service { letter-spacing: 0 !important; font-size: 30px !important; } .cta { box-shadow: none !important; border: 3px solid #f8dc97 !important; background: #1fce6d !important; }';
      copia.head.append(ajustes);
    }
  });
  const blob = await new Promise(r => lienzo.toBlob(r, 'image/png'));
  return new File([blob], nombre, { type: 'image/png' });
}

function descargar(archivo) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(archivo);
  a.download = archivo.name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 5000);
}

function prepararCompartir({ mensaje, nombre }) {
  if (exportando) return;

  const barra = document.createElement('div');
  barra.dataset.html2canvasIgnore = 'true';
  barra.style.cssText = 'position:fixed;left:0;right:0;bottom:0;display:flex;gap:24px;padding:24px 36px;background:rgba(4,16,31,.94);z-index:9';
  const base = 'flex:1;min-height:140px;border:0;border-radius:28px;font:800 42px Montserrat,sans-serif;cursor:pointer;';
  const claro = `${base}background:#0c2748;color:#fff;border:3px solid #e9b44c`;
  barra.innerHTML = `<button type="button" id="btnImagen" style="${claro}">Compartir</button>` +
    `<button type="button" id="btnGuardar" style="${claro}">Guardar</button>` +
    `<button type="button" id="btnWhatsApp" style="${base}background:#25d366;color:#03281a">WhatsApp</button>`;
  document.body.append(barra);
  // Espacio para que la barra no tape el final de la pieza
  document.documentElement.style.height = document.body.style.height = '2110px';

  const btnImagen = document.getElementById('btnImagen');
  const btnGuardar = document.getElementById('btnGuardar');
  btnImagen.disabled = btnGuardar.disabled = true;
  btnImagen.textContent = 'Preparando…';
  imagen = prepararImagen(nombre).then(archivo => {
    btnImagen.disabled = btnGuardar.disabled = false;
    btnImagen.textContent = 'Compartir';
    return archivo;
  }).catch(() => {
    btnImagen.textContent = 'No disponible';
    return null;
  });

  btnGuardar.addEventListener('click', async () => {
    const archivo = await imagen;
    if (archivo) descargar(archivo);
  });

  btnImagen.addEventListener('click', async () => {
    const archivo = await imagen;
    if (!archivo) return;
    if (navigator.canShare && navigator.canShare({ files: [archivo] })) {
      try { await navigator.share({ files: [archivo] }); } catch {}
    } else {
      descargar(archivo);
    }
  });

  document.getElementById('btnWhatsApp').addEventListener('click', () => {
    const enlace = location.origin + location.pathname;
    window.open(`https://wa.me/?text=${encodeURIComponent(`${mensaje}\n${enlace}`)}`, '_blank', 'noopener');
  });
}
