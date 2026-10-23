// 掃描保單：在瀏覽器裡把電子保單 PDF、截圖轉成要送去辨識的 JPEG（第 5 階段 E）
// 全部在使用者的裝置上處理：PDF 密碼只用來在本機打開檔案，不會傳出去、不會保存。
// pdf.js 只有第一次用到時才從 cdnjs 載入（PDF 內容不會送到 cdnjs）。
(function () {
  var PDFJS_VERSION = '3.11.174';
  var PDFJS_BASE = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/' + PDFJS_VERSION + '/';
  var MAX_PAGES = 3;          // AI 一次最多看 3 張
  var MAX_LONG_SIDE = 1600;   // 長邊縮到 1600 像素，字看得清楚、檔案又不會太大
  var JPEG_QUALITY = 0.85;
  var pdfjsLoading = null;

  function loadPdfjs() {
    if (window.pdfjsLib) return Promise.resolve(window.pdfjsLib);
    if (pdfjsLoading) return pdfjsLoading;
    pdfjsLoading = new Promise(function (resolve, reject) {
      var script = document.createElement('script');
      script.src = PDFJS_BASE + 'pdf.min.js';
      script.onload = function () {
        window.pdfjsLib.GlobalWorkerOptions.workerSrc = PDFJS_BASE + 'pdf.worker.min.js';
        resolve(window.pdfjsLib);
      };
      script.onerror = function () {
        pdfjsLoading = null;
        reject(new Error('pdfjs_load_failed'));
      };
      document.head.appendChild(script);
    });
    return pdfjsLoading;
  }

  function canvasToBase64(canvas) {
    var dataUrl = canvas.toDataURL('image/jpeg', JPEG_QUALITY);
    return dataUrl.substring(dataUrl.indexOf(',') + 1);
  }

  // 結果一律回傳 JSON 字串：{status, images, pageCount}
  //   status：ok／need_password／wrong_password／error
  window.jingxuanPdfToImages = function (bytes, password) {
    return loadPdfjs().then(function (pdfjsLib) {
      // 一定要給 pdf.js 一份複本：pdf.js 會把收到的資料搬到背景執行緒，原本的陣列會被清空，
      // 不複製的話「需要密碼」之後再帶密碼重試時，拿到的會是空檔案（2026-10-24 沛沛實測發現）
      var options = { data: new Uint8Array(bytes) };
      if (password) options.password = password;
      return pdfjsLib.getDocument(options).promise;
    }).then(function (pdf) {
      var pageCount = Math.min(pdf.numPages, MAX_PAGES);
      var images = [];
      var chain = Promise.resolve();
      for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
        (function (number) {
          chain = chain.then(function () {
            return pdf.getPage(number).then(function (page) {
              var baseViewport = page.getViewport({ scale: 1 });
              var longSide = Math.max(baseViewport.width, baseViewport.height);
              var viewport = page.getViewport({ scale: MAX_LONG_SIDE / longSide });
              var canvas = document.createElement('canvas');
              canvas.width = Math.round(viewport.width);
              canvas.height = Math.round(viewport.height);
              var context = canvas.getContext('2d');
              context.fillStyle = '#ffffff';
              context.fillRect(0, 0, canvas.width, canvas.height);
              // intent 'print'：一次畫完、不等瀏覽器的動畫時間點，分頁在背景時也不會卡住
              return page.render({ canvasContext: context, viewport: viewport, intent: 'print' }).promise.then(function () {
                images.push(canvasToBase64(canvas));
              });
            });
          });
        })(pageNumber);
      }
      return chain.then(function () {
        var totalPages = pdf.numPages;
        pdf.destroy();
        return JSON.stringify({ status: 'ok', images: images, pageCount: totalPages });
      });
    }).catch(function (error) {
      var name = error && error.name;
      var code = error && error.code;
      if (name === 'PasswordException') {
        // pdf.js：1 = 需要密碼，2 = 密碼錯誤
        return JSON.stringify({ status: code === 2 ? 'wrong_password' : 'need_password' });
      }
      return JSON.stringify({ status: 'error' });
    });
  };

  // 截圖、照片：縮到長邊 1600 並轉成 JPEG
  window.jingxuanImageToJpeg = function (bytes, mimeType) {
    return new Promise(function (resolve) {
      var blob = new Blob([bytes], { type: mimeType || 'image/jpeg' });
      var url = URL.createObjectURL(blob);
      var image = new Image();
      image.onload = function () {
        var scale = Math.min(1, MAX_LONG_SIDE / Math.max(image.width, image.height));
        var canvas = document.createElement('canvas');
        canvas.width = Math.round(image.width * scale);
        canvas.height = Math.round(image.height * scale);
        var context = canvas.getContext('2d');
        context.fillStyle = '#ffffff';
        context.fillRect(0, 0, canvas.width, canvas.height);
        context.drawImage(image, 0, 0, canvas.width, canvas.height);
        URL.revokeObjectURL(url);
        resolve(JSON.stringify({ status: 'ok', images: [canvasToBase64(canvas)] }));
      };
      image.onerror = function () {
        URL.revokeObjectURL(url);
        resolve(JSON.stringify({ status: 'error' }));
      };
      image.src = url;
    });
  };
})();
