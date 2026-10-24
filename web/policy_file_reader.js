// 掃描保單：在瀏覽器裡把電子保單 PDF、截圖轉成要送去辨識的 JPEG（第 5 階段 E）
// 全部在使用者的裝置上處理：PDF 密碼只用來在本機打開檔案，不會傳出去、不會保存。
// pdf.js 只有第一次用到時才從 cdnjs 載入（PDF 內容不會送到 cdnjs）。
(function () {
  var PDFJS_VERSION = '3.11.174';
  var PDFJS_BASE = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/' + PDFJS_VERSION + '/';
  var MAX_PAGES = 3;          // AI 一次最多看 3 張
  var MAX_LONG_SIDE = 1600;   // 長邊縮到 1600 像素，字看得清楚、檔案又不會太大
  var MAX_PHOTO_LONG_SIDE = 2000;  // 照片多留一點細節：之後切上下兩半時，每半還有約 1600 寬
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

  // 截圖、照片：縮到長邊 2000 並轉成 JPEG
  window.jingxuanImageToJpeg = function (bytes, mimeType) {
    return new Promise(function (resolve) {
      var blob = new Blob([bytes], { type: mimeType || 'image/jpeg' });
      var url = URL.createObjectURL(blob);
      var image = new Image();
      image.onload = function () {
        var scale = Math.min(1, MAX_PHOTO_LONG_SIDE / Math.max(image.width, image.height));
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

  // ---------------------------------------------------------------------------
  // A. 照片切成上下兩半（2026-10-25：南山 11 列的密表格會漏列、錯位）
  // AI 會把每張圖縮成固定大小，切兩半等於把字放大一倍；中間重疊 12%，避免剛好切在某一列上
  // ---------------------------------------------------------------------------
  var SPLIT_OVERLAP = 0.12;

  window.jingxuanSplitImage = function (bytes) {
    return new Promise(function (resolve) {
      var blob = new Blob([bytes], { type: 'image/jpeg' });
      var url = URL.createObjectURL(blob);
      var image = new Image();
      image.onload = function () {
        var halfHeight = Math.round(image.height * (0.5 + SPLIT_OVERLAP / 2));
        var tops = [0, image.height - halfHeight];
        var images = [];
        for (var index = 0; index < tops.length; index++) {
          var scale = Math.min(1, MAX_LONG_SIDE / Math.max(image.width, halfHeight));
          var canvas = document.createElement('canvas');
          canvas.width = Math.round(image.width * scale);
          canvas.height = Math.round(halfHeight * scale);
          var context = canvas.getContext('2d');
          context.fillStyle = '#ffffff';
          context.fillRect(0, 0, canvas.width, canvas.height);
          context.drawImage(image, 0, tops[index], image.width, halfHeight, 0, 0, canvas.width, canvas.height);
          images.push(canvasToBase64(canvas));
        }
        URL.revokeObjectURL(url);
        resolve(JSON.stringify({ status: 'ok', images: images }));
      };
      image.onerror = function () {
        URL.revokeObjectURL(url);
        resolve(JSON.stringify({ status: 'error' }));
      };
      image.src = url;
    });
  };

  // ---------------------------------------------------------------------------
  // B. 電子保單 PDF 直接取出文字（不轉成圖片給 AI 認字）
  // 同一行的字依左右位置排好，字距大的地方用「 | 」隔開，讓 AI 看得出表格欄位
  // 個資先在本機遮掉：姓名、身分證字號、出生日期、電話、帳號、Email（③ 版的 PDF 部分）
  // ---------------------------------------------------------------------------
  var MIN_TEXT_LENGTH = 40;   // 少於這麼多字，當作是掃描成圖片的 PDF，改回用圖片辨識

  function maskPersonalData(text) {
    var lines = text.split('\n').map(function (line) {
      // 「要保人 | 王測試 | 被保險人 | …」：標籤後面那一格是姓名（表格窄時「被保險人」會被拆成「被保險」＋「人」）
      line = line.replace(/(要保人|被保險人?|受益人|法定代理人)(\s*[|｜:：]\s*)([^|｜\n]+)/g, '$1$2［姓名已遮蔽］');
      // 有「出生」「生日」的那一行，日期一律遮掉（生效日在別行，不受影響）
      if (/出生|生日/.test(line)) {
        line = line.replace(/\d{2,4}\s*[\/.年-]\s*\d{1,2}\s*[\/.月-]\s*\d{1,2}\s*日?/g, '［出生日期已遮蔽］');
      }
      return line;
    });
    return lines.join('\n')
      .replace(/[A-Z][12489]\d{8}/g, '［身分證已遮蔽］')
      .replace(/\d{3,}-\d{4,}-\d{2,}/g, '［帳號已遮蔽］')
      .replace(/09\d{2}-?\d{3}-?\d{3}/g, '［電話已遮蔽］')
      .replace(/0\d{1,2}-\d{3,4}-\d{4}/g, '［電話已遮蔽］')
      .replace(/[\w.+-]+@[\w-]+\.[\w.]+/g, '［Email已遮蔽］');
  }

  function pageItemsToLines(items) {
    var rows = [];
    for (var index = 0; index < items.length; index++) {
      var item = items[index];
      var text = (item.str || '').trim();
      if (!text) continue;
      // 斜的字（浮水印、印章）跳過，不然會混進表格裡
      if (Math.abs(item.transform[1]) > 0.01 || Math.abs(item.transform[2]) > 0.01) continue;
      var x = item.transform[4];
      var y = item.transform[5];
      var height = Math.abs(item.transform[3]) || 10;
      var row = null;
      for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
        if (Math.abs(rows[rowIndex].y - y) < height * 0.5) { row = rows[rowIndex]; break; }
      }
      if (!row) { row = { y: y, height: height, parts: [] }; rows.push(row); }
      row.parts.push({ x: x, width: item.width || 0, text: text });
    }
    rows.sort(function (first, second) { return second.y - first.y; });
    var lines = [];
    for (var lineIndex = 0; lineIndex < rows.length; lineIndex++) {
      var parts = rows[lineIndex].parts.sort(function (first, second) { return first.x - second.x; });
      var line = parts[0].text;
      for (var partIndex = 1; partIndex < parts.length; partIndex++) {
        var previous = parts[partIndex - 1];
        var gap = parts[partIndex].x - (previous.x + previous.width);
        line += (gap > rows[lineIndex].height * 0.8 ? ' | ' : '') + parts[partIndex].text;
      }
      lines.push(line);
    }
    return lines.join('\n');
  }

  // 結果：{status: ok／need_password／wrong_password／no_text／error, text}
  window.jingxuanPdfToText = function (bytes, password) {
    return loadPdfjs().then(function (pdfjsLib) {
      var options = { data: new Uint8Array(bytes) };
      if (password) options.password = password;
      return pdfjsLib.getDocument(options).promise;
    }).then(function (pdf) {
      var pageCount = Math.min(pdf.numPages, MAX_PAGES);
      var pageTexts = [];
      var chain = Promise.resolve();
      for (var pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
        (function (number) {
          chain = chain.then(function () {
            return pdf.getPage(number).then(function (page) {
              return page.getTextContent().then(function (content) {
                pageTexts.push('【第 ' + number + ' 頁】\n' + pageItemsToLines(content.items));
              });
            });
          });
        })(pageNumber);
      }
      return chain.then(function () {
        pdf.destroy();
        // NFKC：把「⼭」「⼈」這類部首字、全形英數統一成一般寫法，AI 和目錄比對才不會對不上
        var text = pageTexts.join('\n\n').normalize('NFKC');
        var plainLength = text.replace(/【第 \d+ 頁】|\s|\|/g, '').length;
        if (plainLength < MIN_TEXT_LENGTH) return JSON.stringify({ status: 'no_text' });
        return JSON.stringify({ status: 'ok', text: maskPersonalData(text) });
      });
    }).catch(function (error) {
      if (error && error.name === 'PasswordException') {
        return JSON.stringify({ status: error.code === 2 ? 'wrong_password' : 'need_password' });
      }
      return JSON.stringify({ status: 'error' });
    });
  };
})();
