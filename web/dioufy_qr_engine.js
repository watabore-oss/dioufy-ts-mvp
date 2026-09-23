/**
 * Dioufy-TS Universal QR Engine (v3.5 - Standard Industriel Multiplateforme Durci)
 * 
 * Architecture scientifique et résiliente :
 * 1. Élimination Écran Noir : Recherche récursive dans les ShadowRoots de Flutter CanvasKit et retries de montage DOM.
 * 2. Sélecteur Galerie Web Direct : Ouverture native du file-picker avec FileReader et décodage 100% local.
 * 3. Accélération matérielle opportuniste : API W3C BarcodeDetector réutilisée sans recréation par frame.
 * 4. Filet de sécurité garanti : jsQR local embarqué (100% offline, autonome, zéro CDN, compatible iOS & Android).
 * 5. Caméra HTML5 durcie : Safari iOS (playsinline DOM + attribute), Chrome Android PWA.
 * 6. Throttle CPU intelligent : 100ms (~10 FPS) évitant la surchauffe et préservant la batterie.
 */

(function () {
  'use strict';

  // Registre des instances actives de caméras
  window.__dioufyActiveCameras = window.__dioufyActiveCameras || {};

  // Instance globale réutilisable pour éviter la surconsommation CPU
  let _cachedBarcodeDetector = null;
  if ('BarcodeDetector' in window) {
    try {
      _cachedBarcodeDetector = new BarcodeDetector({ formats: ['qr_code'] });
    } catch (_) {}
  }

  /**
   * Recherche récursive d'un élément dans le document et dans TOUS les Shadow DOMs
   * (Nécessaire car Flutter Web CanvasKit encapsule les PlatformViews dans des ShadowRoots)
   */
  function findElementDeep(idOrElement) {
    if (!idOrElement) return null;
    if (typeof idOrElement === 'object' && idOrElement.nodeType) {
      return idOrElement;
    }

    const id = String(idOrElement);
    const direct = document.getElementById(id);
    if (direct) return direct;

    function searchTree(root) {
      if (!root) return null;
      if (root.getElementById) {
        const found = root.getElementById(id);
        if (found) return found;
      }
      const children = root.children || [];
      for (let i = 0; i < children.length; i++) {
        const child = children[i];
        if (child.id === id) return child;
        if (child.shadowRoot) {
          const inShadow = searchTree(child.shadowRoot);
          if (inShadow) return inShadow;
        }
        const inChild = searchTree(child);
        if (inChild) return inChild;
      }
      return null;
    }

    return searchTree(document.body);
  }

  /**
   * 1. Décodage local autonome d'une image fixe (Galerie / Photo / WhatsApp)
   * @param {string} dataUrl - URL base64 ou blob de l'image
   * @returns {Promise<string|null>} - Le texte du QR code décodé ou null
   */
  window.dioufyDecodeImage = function (dataUrl) {
    return new Promise(function (resolve) {
      if (!dataUrl || typeof dataUrl !== 'string' || dataUrl.trim().length < 20) {
        resolve(null);
        return;
      }

      const img = new Image();
      img.crossOrigin = 'anonymous';

      img.onload = async function () {
        try {
          // Palier 1 : Accélération opportuniste BarcodeDetector
          if (_cachedBarcodeDetector) {
            try {
              const barcodes = await _cachedBarcodeDetector.detect(img);
              if (barcodes && barcodes.length > 0 && barcodes[0].rawValue) {
                resolve(barcodes[0].rawValue.trim());
                return;
              }
            } catch (_) {}
          }

          // Palier 2 : Filet de sécurité garanti via jsQR local
          if (typeof jsQR !== 'function') {
            console.warn('[DioufyQR] jsQR local non disponible');
            resolve(null);
            return;
          }

          const canvas = document.createElement('canvas');
          const ctx = canvas.getContext('2d', { willReadFrequently: true });
          if (!ctx) {
            resolve(null);
            return;
          }

          // Échantillonnage optimisé
          const maxDim = 800;
          let w = img.naturalWidth || img.width;
          let h = img.naturalHeight || img.height;

          if (w <= 0 || h <= 0) {
            resolve(null);
            return;
          }

          if (w > maxDim || h > maxDim) {
            if (w > h) {
              h = Math.round((h * maxDim) / w);
              w = maxDim;
            } else {
              w = Math.round((w * maxDim) / h);
              h = maxDim;
            }
          }

          canvas.width = w;
          canvas.height = h;
          ctx.drawImage(img, 0, 0, w, h);

          const imgData = ctx.getImageData(0, 0, w, h);
          const qr = jsQR(imgData.data, w, h, {
            inversionAttempts: 'attemptBoth',
          });

          if (qr && qr.data && qr.data.trim().length > 0) {
            resolve(qr.data.trim());
            return;
          }

          // Scan supplémentaire centré (optimisation pour gros plans)
          if (w > 300 && h > 300) {
            const cropSize = Math.round(Math.min(w, h) * 0.75);
            const cropCanvas = document.createElement('canvas');
            cropCanvas.width = cropSize;
            cropCanvas.height = cropSize;
            const cropCtx = cropCanvas.getContext('2d', { willReadFrequently: true });
            if (cropCtx) {
              const sx = Math.round((w - cropSize) / 2);
              const sy = Math.round((h - cropSize) / 2);
              cropCtx.drawImage(img, sx, sy, cropSize, cropSize, 0, 0, cropSize, cropSize);
              const cropData = cropCtx.getImageData(0, 0, cropSize, cropSize);
              const cropQr = jsQR(cropData.data, cropSize, cropSize, {
                inversionAttempts: 'attemptBoth',
              });
              if (cropQr && cropQr.data && cropQr.data.trim().length > 0) {
                resolve(cropQr.data.trim());
                return;
              }
            }
          }

          resolve(null);
        } catch (err) {
          console.error('[DioufyQR] Erreur décodage image:', err);
          resolve(null);
        }
      };

      img.onerror = function () {
        console.error('[DioufyQR] Erreur chargement image fixe');
        resolve(null);
      };

      img.src = dataUrl;
    });
  };

  /**
   * 2. Sélecteur Galerie Web Direct (Universal File Picker PWA/Mobile)
   * Déclenche la galerie du terminal de façon 100% synchrone et renvoie le code QR décodé.
   */
  function _getOrCreateGalleryInput() {
    let input = document.getElementById('dioufy_web_gallery_input');
    if (!input) {
      input = document.createElement('input');
      input.id = 'dioufy_web_gallery_input';
      input.type = 'file';
      input.accept = 'image/jpeg,image/png,image/webp,image/*';
      input.style.position = 'fixed';
      input.style.top = '-10000px';
      input.style.left = '-10000px';
      input.style.opacity = '0';
      input.style.pointerEvents = 'none';
      (document.body || document.documentElement).appendChild(input);
    }
    return input;
  }

  // Préparation immédiate de l'input dans le DOM
  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', _getOrCreateGalleryInput);
    } else {
      _getOrCreateGalleryInput();
    }
  }

  window.dioufyPickImageFromGallery = function () {
    return new Promise(function (resolve) {
      const input = _getOrCreateGalleryInput();
      input.value = '';

      input.onchange = function (event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
          resolve(null);
          return;
        }

        const reader = new FileReader();
        reader.onload = async function (e) {
          const dataUrl = e.target.result;
          if (!dataUrl || typeof dataUrl !== 'string' || dataUrl.length < 50) {
            resolve(null);
            return;
          }
          const decoded = await window.dioufyDecodeImage(dataUrl);
          resolve(decoded);
        };
        reader.onerror = function () {
          resolve(null);
        };
        reader.readAsDataURL(file);
      };

      input.oncancel = function () {
        resolve(null);
      };

      // Déclenchement synchrone
      input.click();
    });
  };

  /**
   * 3. Démarrage de la Caméra Web Durcie (iOS Safari, Android Chrome, PWA)
   */
  window.dioufyStartCamera = async function (containerOrId, onDetect, onError, initialFacing) {
    const containerKey = typeof containerOrId === 'string' ? containerOrId : (containerOrId.id || 'dioufy_cam_default');

    // Si une caméra est déjà active avec ce même conteneur, mettre à jour les écouteurs sans redémarrer
    const existing = window.__dioufyActiveCameras && window.__dioufyActiveCameras[containerKey];
    if (existing && existing.stream && existing.stream.active) {
      existing.onDetect = onDetect;
      existing.onError = onError;
      return;
    }

    window.dioufyStopCamera(containerKey);

    // Recherche de l'élément avec retries de montage pour Flutter Web
    let container = findElementDeep(containerOrId);
    if (!container) {
      for (let attempt = 0; attempt < 30; attempt++) {
        await new Promise(r => setTimeout(r, 60));
        container = findElementDeep(containerOrId);
        if (container) break;
      }
    }

    if (!container) {
      console.warn('[DioufyQR] Conteneur non trouvé après 1.8s:', containerKey);
      if (typeof onError === 'function') {
        onError('CONTAINER_NOT_FOUND', 'Conteneur caméra introuvable.');
      }
      return;
    }

    // Affichage immédiat d'un indicateur de chargement pour éliminer l'effet "écran noir vide"
    container.innerHTML = '';
    const loaderDiv = document.createElement('div');
    loaderDiv.id = 'dioufy_loader_' + containerKey;
    loaderDiv.style.cssText = 'position:absolute;top:0;left:0;right:0;bottom:0;display:flex;flex-direction:column;align-items:center;justify-content:center;color:#38BDF8;font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:13px;z-index:1;background:#0F172A;text-align:center;padding:16px;';
    loaderDiv.innerHTML = '<div style="width:36px;height:36px;border:3px solid rgba(56,189,248,0.2);border-top-color:#38BDF8;border-radius:50%;animation:spin 1s linear infinite;margin-bottom:12px;"></div><span style="font-weight:600;">Activation de la caméra...</span><span style="font-size:11px;color:#94A3B8;margin-top:4px;">Veuillez autoriser l\'accès si demandé</span>';
    container.appendChild(loaderDiv);

    if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
      loaderDiv.innerHTML = '<span style="color:#F87171;font-weight:bold;">Accès caméra non supporté sur ce navigateur</span>';
      if (typeof onError === 'function') {
        onError('UNSUPPORTED', 'Votre navigateur ne supporte pas l\'accès direct à la caméra.');
      }
      return;
    }

    let facing = initialFacing === 'user' ? 'user' : 'environment';
    let stream = null;

    const constraints1 = {
      audio: false,
      video: {
        facingMode: { ideal: facing },
        width: { ideal: 1280 },
        height: { ideal: 720 },
      },
    };

    const constraints2 = {
      audio: false,
      video: { facingMode: facing },
    };

    const constraints3 = {
      audio: false,
      video: true,
    };

    try {
      try {
        stream = await navigator.mediaDevices.getUserMedia(constraints1);
      } catch (err1) {
        console.warn('[DioufyQR] Contraintes 1 échouées, essai palier 2:', err1);
        try {
          stream = await navigator.mediaDevices.getUserMedia(constraints2);
        } catch (err2) {
          console.warn('[DioufyQR] Contraintes 2 échouées, essai palier 3:', err2);
          stream = await navigator.mediaDevices.getUserMedia(constraints3);
        }
      }
    } catch (finalErr) {
      let errCode = 'GENERIC_CAMERA_ERROR';
      let errMsg = 'Impossible d\'activer le capteur caméra.';

      if (finalErr.name === 'NotAllowedError' || finalErr.name === 'PermissionDeniedError') {
        errCode = 'PERMISSION_DENIED';
        errMsg = 'Autorisation caméra refusée. Veuillez autoriser l\'accès dans les paramètres du navigateur.';
      } else if (finalErr.name === 'NotFoundError' || finalErr.name === 'DevicesNotFoundError') {
        errCode = 'NO_CAMERA_FOUND';
        errMsg = 'Aucun capteur photo détecté sur cet appareil.';
      } else if (finalErr.name === 'NotReadableError' || finalErr.name === 'TrackStartError') {
        errCode = 'CAMERA_BUSY';
        errMsg = 'Le capteur photo est actuellement occupé par une autre application.';
      }

      loaderDiv.innerHTML = '<div style="font-size:28px;margin-bottom:8px;">📷</div><div style="font-weight:bold;color:#F87171;margin-bottom:6px;">Accès Caméra Bloqué</div><div style="font-size:11.5px;color:#CBD5E1;max-width:280px;line-height:1.4;">' + errMsg + '</div>';

      if (typeof onError === 'function') {
        onError(errCode, errMsg);
      }
      return;
    }

    // Création de l'élément vidéo durci
    const video = document.createElement('video');
    video.setAttribute('playsinline', '');
    video.setAttribute('webkit-playsinline', '');
    video.setAttribute('autoplay', '');
    video.setAttribute('muted', '');
    video.playsInline = true;
    video.autoplay = true;
    video.muted = true;
    video.controls = false;

    video.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;object-fit:cover;background:#000000;z-index:0;';
    container.appendChild(video);
    video.srcObject = stream;

    // Canvas hors-écran pour analyse continue
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d', { willReadFrequently: true });

    let isScanning = true;
    let scanInterval = null;
    let lastScanTime = 0;
    let isTorchActive = false;

    // Masquage du loader dès que le flux est visible
    const onStreamReady = function () {
      if (loaderDiv && loaderDiv.parentNode) {
        loaderDiv.parentNode.removeChild(loaderDiv);
      }
    };
    video.onloadeddata = onStreamReady;
    video.onplaying = onStreamReady;

    // Détection continue (~10 FPS pour préserver la batterie et éviter la chauffe CPU)
    const analyzeFrame = async function () {
      if (!isScanning) return;

      const now = Date.now();
      if (now - lastScanTime < 100) return; // 100ms = 10 FPS optimisé
      lastScanTime = now;

      if (video.readyState < video.HAVE_CURRENT_DATA) return;
      if (video.videoWidth <= 0 || video.videoHeight <= 0) return;

      try {
        // Palier 1 : Accélération matérielle BarcodeDetector
        if (_cachedBarcodeDetector) {
          try {
            const barcodes = await _cachedBarcodeDetector.detect(video);
            if (barcodes && barcodes.length > 0 && barcodes[0].rawValue) {
              const code = barcodes[0].rawValue.trim();
              if (code.length > 0 && typeof onDetect === 'function') {
                isScanning = false;
                onDetect(code);
                return;
              }
            }
          } catch (_) {}
        }

        // Palier 2 : jsQR local garanti
        if (typeof jsQR === 'function' && ctx) {
          const vw = video.videoWidth;
          const vh = video.videoHeight;
          if (vw > 0 && vh > 0) {
            const scanDim = Math.min(vw, vh);
            const sx = (vw - scanDim) / 2;
            const sy = (vh - scanDim) / 2;

            const sampleSize = 400;
            canvas.width = sampleSize;
            canvas.height = sampleSize;

            ctx.drawImage(video, sx, sy, scanDim, scanDim, 0, 0, sampleSize, sampleSize);
            const imgData = ctx.getImageData(0, 0, sampleSize, sampleSize);

            const qr = jsQR(imgData.data, sampleSize, sampleSize, {
              inversionAttempts: 'attemptBoth',
            });

            if (qr && qr.data && qr.data.trim().length > 0) {
              isScanning = false;
              if (typeof onDetect === 'function') {
                onDetect(qr.data.trim());
              }
            }
          }
        }
      } catch (loopErr) {
        // Ignorer erreurs transitoires
      }
    };

    const startPlayback = function () {
      if (video.paused) {
        video.play().catch(function (e) {
          console.warn('[DioufyQR] Play différé:', e);
        });
      }
      if (!scanInterval) {
        scanInterval = setInterval(analyzeFrame, 100);
      }
    };

    video.onloadedmetadata = startPlayback;
    startPlayback();

    // Enregistrement de l'instance
    window.__dioufyActiveCameras[containerKey] = {
      stream: stream,
      video: video,
      facing: facing,
      onDetect: onDetect,
      onError: onError,
      get isTorchOn() {
        return isTorchActive;
      },
      isTorchSupported: function () {
        if (!stream) return false;
        const tracks = stream.getVideoTracks();
        if (tracks.length === 0) return false;
        const caps = tracks[0].getCapabilities ? tracks[0].getCapabilities() : {};
        return Boolean(caps.torch);
      },
      toggleTorch: async function () {
        if (!stream) return false;
        const tracks = stream.getVideoTracks();
        if (tracks.length === 0) return false;
        const track = tracks[0];
        const caps = track.getCapabilities ? track.getCapabilities() : {};
        if (!caps.torch) return false;

        isTorchActive = !isTorchActive;
        try {
          await track.applyConstraints({
            advanced: [{ torch: isTorchActive }],
          });
          return true;
        } catch (e) {
          console.warn('[DioufyQR] Erreur activation torche:', e);
          isTorchActive = !isTorchActive;
          return false;
        }
      },
      switchCamera: async function () {
        const nextFacing = facing === 'environment' ? 'user' : 'environment';
        await window.dioufyStartCamera(containerKey, onDetect, onError, nextFacing);
        return nextFacing;
      },
      capturePhoto: async function () {
        if (!video || video.videoWidth === 0) return null;
        try {
          const photoCanvas = document.createElement('canvas');
          photoCanvas.width = video.videoWidth || 1280;
          photoCanvas.height = video.videoHeight || 720;
          const photoCtx = photoCanvas.getContext('2d', { willReadFrequently: true });
          if (!photoCtx) return null;

          photoCtx.drawImage(video, 0, 0, photoCanvas.width, photoCanvas.height);
          const dataUrl = photoCanvas.toDataURL('image/jpeg', 0.92);
          return await window.dioufyDecodeImage(dataUrl);
        } catch (e) {
          console.error('[DioufyQR] Échec capture photo HD:', e);
          return null;
        }
      },
      stop: function () {
        isScanning = false;
        if (scanInterval) {
          clearInterval(scanInterval);
          scanInterval = null;
        }
        if (stream) {
          stream.getTracks().forEach(function (t) {
            try {
              t.stop();
            } catch (_) {}
          });
        }
        if (video && video.parentNode) {
          video.parentNode.removeChild(video);
        }
        if (loaderDiv && loaderDiv.parentNode) {
          loaderDiv.parentNode.removeChild(loaderDiv);
        }
      },
    };
  };

  /**
   * 4. Arrêt et libération des flux caméra
   */
  window.dioufyStopCamera = function (containerKey) {
    if (window.__dioufyActiveCameras && window.__dioufyActiveCameras[containerKey]) {
      try {
        window.__dioufyActiveCameras[containerKey].stop();
      } catch (e) {
        console.warn('[DioufyQR] Erreur arrêt caméra:', e);
      }
      delete window.__dioufyActiveCameras[containerKey];
    }
  };

  window.dioufyIsTorchSupported = function (containerKey) {
    const cam = window.__dioufyActiveCameras && window.__dioufyActiveCameras[containerKey];
    return cam ? cam.isTorchSupported() : false;
  };

  window.dioufyIsTorchOn = function (containerKey) {
    const cam = window.__dioufyActiveCameras && window.__dioufyActiveCameras[containerKey];
    return cam ? cam.isTorchOn : false;
  };

  window.dioufyToggleTorch = async function (containerKey) {
    const cam = window.__dioufyActiveCameras && window.__dioufyActiveCameras[containerKey];
    return cam ? await cam.toggleTorch() : false;
  };

  window.dioufySwitchCamera = async function (containerKey) {
    const cam = window.__dioufyActiveCameras && window.__dioufyActiveCameras[containerKey];
    return cam ? await cam.switchCamera() : 'environment';
  };

  window.dioufyCapturePhoto = async function (containerKey) {
    const cam = window.__dioufyActiveCameras && window.__dioufyActiveCameras[containerKey];
    return cam ? await cam.capturePhoto() : null;
  };
})();
