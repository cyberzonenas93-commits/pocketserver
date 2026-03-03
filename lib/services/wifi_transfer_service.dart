import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:mdns_dart/mdns_dart.dart';
import 'package:mdns_responder/mdns_responder.dart';
import 'package:mime/mime.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path/path.dart' as path;
import '../models/transfer_item.dart';
import 'monetization/monetization_service.dart';
import 'transfer_storage.dart';

/// HTTP server for WiFi transfer: upload/download files between devices on same WiFi.
class WiFiTransferService extends ChangeNotifier {
  WiFiTransferService(this._storage, this._monetization);

  final TransferStorage _storage;
  final MonetizationService _monetization;

  HttpServer? _server;
  MDNSServer? _mdnsServer;
  bool _usedNativeMdns = false;
  String? _serverUrl;
  bool _isRunning = false;
  bool _mdnsDiscoverable = false;
  int _port = 8080;
  bool _isReceiving = false;
  bool _showUploadComplete = false;
  Timer? _uploadCompleteTimer;
  String? _webPin;

  static const int _maxUploadBytesFree = 300 * 1024 * 1024; // 300MB
  static const int _maxUploadBytesPro = 5 * 1024 * 1024 * 1024; // 5GB

  int _getMaxUploadBytes() =>
      _monetization.isPro ? _maxUploadBytesPro : _maxUploadBytesFree;

  bool get isRunning => _isRunning;
  bool get isReceiving => _isReceiving;
  bool get showUploadComplete => _showUploadComplete;
  String? get serverUrl => _serverUrl;
  int get port => _port;
  bool get isDiscoverableOnNetwork => _mdnsDiscoverable;
  bool get isReachableFromNetwork =>
      _serverUrl != null &&
      !_serverUrl!.contains('localhost') &&
      !_serverUrl!.contains('127.0.0.1');
  bool get isLikelyEmulator =>
      Platform.isAndroid &&
      _serverUrl != null &&
      (_serverUrl!.contains('10.0.2.') || _serverUrl!.startsWith('http://10.0.2.'));

  Future<String> _getLocalIP() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final info = NetworkInfo();
        final wifiIP = await info.getWifiIP();
        if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '127.0.0.1') return wifiIP;
      } catch (e) {
        debugPrint('[WiFiTransfer] network_info_plus: $e');
      }
    }
    try {
      final interfaces = await NetworkInterface.list();
      String? wifiIp;
      String? fallbackIp;
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.startsWith('pdp_') || name == 'awdl0' || name.startsWith('utun')) continue;
        for (final addr in interface.addresses) {
          if (addr.type != InternetAddressType.IPv4 || addr.isLoopback) continue;
          final ip = addr.address;
          if (name == 'en0' || name == 'wlan0') {
            wifiIp ??= ip;
            break;
          }
          fallbackIp ??= ip;
        }
      }
      final chosen = wifiIp ?? fallbackIp;
      if (chosen != null && chosen != '127.0.0.1') return chosen;
    } catch (e) {
      debugPrint('[WiFiTransfer] NetworkInterface: $e');
    }
    try {
      final info = NetworkInfo();
      final wifiIP = await info.getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty && wifiIP != '127.0.0.1') return wifiIP;
    } catch (e) {
      debugPrint('[WiFiTransfer] network_info_plus: $e');
    }
    return 'localhost';
  }

  Response _cors(Response res) {
    return res.change(headers: {
      ...res.headers,
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    });
  }

  Middleware _corsOptionsMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        if (request.method.toUpperCase() == 'OPTIONS') return _cors(Response.ok(''));
        return handler(request);
      };
    };
  }

  Future<Response> _handleIndex(Request request) async {
    final isPro = _monetization.isPro;
    final pinSet = _webPin != null && _webPin!.isNotEmpty;
    final html = _buildIndexHtml(isPro: isPro, pinSet: pinSet);
    return _cors(Response.ok(html, headers: {'Content-Type': 'text/html; charset=utf-8'}));
  }

  String _buildIndexHtml({required bool isPro, required bool pinSet}) {
    final items = _storage.items;
    final downloadAllHtml = items.isEmpty
        ? ''
        : '<p><a href="/download-all${pinSet ? '?pin=${_escapeUri(_webPin!)}' : ''}" class="btn">Download all as ZIP</a></p>';
    final rows = items.map((item) {
      final size = _formatBytes(item.sizeBytes);
      final downloadUrl = '/download/${item.id}${pinSet ? '?pin=${_escapeUri(_webPin!)}' : ''}';
      final deleteBtn = isPro
          ? '<button type="button" class="btn-delete" data-id="${_escape(item.id)}">Delete</button>'
          : '';
      final renameBtn = isPro
          ? '<button type="button" class="btn-rename" data-id="${_escape(item.id)}" data-name="${_escape(item.displayName)}">Rename</button>'
          : '';
      final actionsCell = isPro ? '<td class="actions">$deleteBtn $renameBtn</td>' : '';
      return '<tr><td class="thumb"><span class="thumb-placeholder">&#128196;</span></td><td><a href="$downloadUrl" download>${_escape(item.displayName)}</a></td><td>$size</td>$actionsCell</tr>';
    }).join();
    final tableHtml = items.isEmpty
        ? '<p>No files yet. Upload from the form above.</p>'
        : '<table><thead><tr><th></th><th>File</th><th>Size</th>${isPro ? '<th></th>' : ''}</tr></thead><tbody>$rows</tbody></table>';
    final upgradeNotice = isPro
        ? ''
        : '<p class="upgrade-notice">Upgrade to Pro for delete, rename, PIN protection, and more.</p>';
    final pinSection = isPro
        ? '<div class="pin-section"><h2>PIN protection</h2><p>Optional: set a PIN to require for downloads.</p><input type="password" id="pinInput" placeholder="PIN"><button type="button" id="setPinBtn">Set PIN</button><button type="button" id="clearPinBtn">Clear PIN</button></div>'
        : '';

    return '''
<!DOCTYPE html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>PocketServer</title>
<style>body{font-family:system-ui;background:#0e0e11;color:#f5f5f7;margin:1rem;max-width:720px;margin-left:auto;margin-right:auto;}
h1{color:#2ee6a6;} h2{font-size:1.1rem;color:#2ee6a6;margin-top:1.5rem;}
a{color:#2ee6a6;} a.btn{display:inline-block;background:#2ee6a6;color:#0e0e11;padding:0.5rem 1rem;border-radius:8px;text-decoration:none;margin:0.5rem 0;}
table{width:100%;border-collapse:collapse;} th,td{padding:0.5rem;text-align:left;border-bottom:1px solid #2a2a30;} th{color:#888;}
td.thumb{width:56px;padding:0.25rem;vertical-align:middle;}
.thumb-img{width:48px;height:48px;object-fit:cover;border-radius:6px;display:block;}
.thumb-placeholder{width:48px;height:48px;border-radius:6px;background:#2a2a30;display:inline-flex;align-items:center;justify-content:center;font-size:1.2rem;}
.hidden{display:none !important;}
input[type=file],button{padding:0.5rem 1rem;margin:0.5rem 0;} button{background:#2ee6a6;color:#0e0e11;border:none;border-radius:8px;cursor:pointer;}
.upload{margin:1.5rem 0;padding:1rem;background:#17171c;border-radius:12px;}
.download{margin:1.5rem 0;padding:1rem;background:#17171c;border-radius:12px;}
.upload-progress{margin:0.5rem 0;display:none;} .upload-progress.visible{display:block;}
.progress-bar{height:8px;background:#2a2a30;border-radius:4px;overflow:hidden;margin:0.25rem 0;}
.progress-fill{height:100%;background:#2ee6a6;transition:width 0.15s ease;}
.upload-status{font-size:0.9rem;color:#c0c0c0;}
.upload-done{font-size:0.9rem;color:#2ee6a6;margin:0.5rem 0;}
.upload-err{font-size:0.9rem;color:#e66;margin:0.5rem 0;}
.btn-delete,.btn-rename{font-size:0.8rem;padding:0.25rem 0.5rem;margin-left:4px;background:#2a2a30;color:#f5f5f7;border:1px solid #444;border-radius:6px;cursor:pointer;}
.btn-delete:hover,.btn-rename:hover{background:#3a3a40;}
.upgrade-notice{font-size:0.85rem;color:#888;margin:0.5rem 0;}
.pin-section{margin:1rem 0;padding:1rem;background:#17171c;border-radius:12px;}
.actions{white-space:nowrap;}</style></head>
<body>
<h1>PocketServer</h1>
<p>Same WiFi only. Send files to this device or get files from it.</p>
$pinSection

<div class="upload">
<h2>Send to device</h2>
<form id="uploadForm" enctype="multipart/form-data">
<input type="file" name="file" multiple id="fileInput">
<button type="submit" id="uploadBtn">Upload</button>
</form>
<div id="uploadProgress" class="upload-progress">
  <div class="progress-bar"><div id="progressFill" class="progress-fill" style="width:0%"></div></div>
  <div id="uploadStatus" class="upload-status">Uploading… 0%</div>
</div>
<div id="uploadDone" class="upload-done" style="display:none">Upload complete.</div>
<div id="uploadErr" class="upload-err" style="display:none"></div>
</div>
<script>
(function(){
  var form = document.getElementById('uploadForm');
  var progress = document.getElementById('uploadProgress');
  var progressFill = document.getElementById('progressFill');
  var status = document.getElementById('uploadStatus');
  var done = document.getElementById('uploadDone');
  var err = document.getElementById('uploadErr');
  var btn = document.getElementById('uploadBtn');
  form.onsubmit = function(e) {
    e.preventDefault();
    var fd = new FormData(form);
    if (!fd.getAll('file').length) return;
    progress.classList.add('visible');
    progressFill.style.width = '0%';
    status.textContent = 'Uploading… 0%';
    done.style.display = 'none';
    err.style.display = 'none';
    btn.disabled = true;
    var xhr = new XMLHttpRequest();
    xhr.upload.onprogress = function(ev) {
      if (ev.lengthComputable) {
        var pct = Math.round(ev.loaded / ev.total * 100);
        progressFill.style.width = pct + '%';
        status.textContent = 'Uploading… ' + pct + '%';
      } else { status.textContent = 'Uploading…'; }
    };
    xhr.onload = function() {
      progress.classList.remove('visible');
      btn.disabled = false;
      if (xhr.status >= 200 && xhr.status < 300) {
        done.style.display = 'block';
        setTimeout(function(){ location.reload(); }, 1500);
      } else {
        err.textContent = xhr.responseText || 'Upload failed';
        err.style.display = 'block';
      }
    };
    xhr.onerror = function() {
      progress.classList.remove('visible');
      btn.disabled = false;
      err.textContent = 'Network error';
      err.style.display = 'block';
    };
    xhr.open('POST', '/upload');
    xhr.send(fd);
    return false;
  };
})();
</script>
</div>

<div class="download">
<h2>Get from device</h2>
<p>Click a file to download it, or get everything as a ZIP.</p>
$upgradeNotice
$downloadAllHtml
$tableHtml
</div>
<script>
(function(){
  var setPinBtn = document.getElementById('setPinBtn');
  var clearPinBtn = document.getElementById('clearPinBtn');
  var pinInput = document.getElementById('pinInput');
  if (setPinBtn && pinInput) {
    setPinBtn.onclick = function() {
      var pin = pinInput.value;
      fetch('/api/set-pin', { method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'pin=' + encodeURIComponent(pin) }).then(function() { location.reload(); });
    };
  }
  if (clearPinBtn) clearPinBtn.onclick = function() {
    fetch('/api/set-pin', { method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'pin=' }).then(function() { location.reload(); });
  };
  document.querySelectorAll('.btn-delete').forEach(function(btn) {
    btn.onclick = function() {
      if (!confirm('Delete this file?')) return;
      var id = btn.getAttribute('data-id');
      fetch('/api/delete', { method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'id=' + encodeURIComponent(id) }).then(function() { location.reload(); });
    };
  });
  document.querySelectorAll('.btn-rename').forEach(function(btn) {
    btn.onclick = function() {
      var name = prompt('New name:', btn.getAttribute('data-name') || '');
      if (name === null || name.trim() === '') return;
      var id = btn.getAttribute('data-id');
      fetch('/api/rename', { method: 'POST', headers: {'Content-Type': 'application/x-www-form-urlencoded'}, body: 'id=' + encodeURIComponent(id) + '&name=' + encodeURIComponent(name.trim()) }).then(function() { location.reload(); });
    };
  });
})();
</script>
</body></html>''';
  }

  String _escapeUri(String s) => Uri.encodeComponent(s);

  String _escape(String s) {
    return s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<Response> _handleList(Request request) async {
    final items = _storage.items.map((i) => {
      'id': i.id,
      'name': i.displayName,
      'size': i.sizeBytes,
      'type': i.type.name,
    }).toList();
    return _cors(Response.ok(
      jsonEncode(items),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<Response> _handleUpload(Request request) async {
    final contentType = request.headers['content-type'];
    if (contentType == null || !contentType.toLowerCase().contains('multipart')) {
      return _cors(Response.badRequest(body: 'Expected multipart/form-data'));
    }
    HeaderValue headerValue;
    try {
      headerValue = HeaderValue.parse(contentType);
    } catch (_) {
      return _cors(Response.badRequest(body: 'Invalid Content-Type'));
    }
    var boundary = headerValue.parameters['boundary']?.trim();
    if (boundary == null || boundary.isEmpty) return _cors(Response.badRequest(body: 'Missing boundary'));
    if ((boundary.startsWith('"') && boundary.endsWith('"')) || (boundary.startsWith("'") && boundary.endsWith("'"))) {
      boundary = boundary.substring(1, boundary.length - 1);
    }
    _isReceiving = true;
    notifyListeners();
    final transformer = MimeMultipartTransformer(boundary);
    try {
      final bytes = await request.read().expand((x) => x).toList();
      if (bytes.length > _getMaxUploadBytes()) {
        return _cors(Response(413, body: 'File too large'));
      }
      int saved = 0;
      await for (final part in Stream.value(bytes).transform(transformer)) {
        final disposition = part.headers['content-disposition'] ?? '';
        final match = RegExp(r'filename="?([^"\r\n]+)"?').firstMatch(disposition);
        if (match == null) continue;
        final filename = (match.group(1) ?? 'upload').replaceAll(RegExp(r'[\r\n]'), '').split('/').last.split(r'\').last;
        if (filename.trim().isEmpty) continue;
        final data = await part.fold(<int>[], (a, b) => [...a, ...b]);
        final u8 = Uint8List.fromList(data);
        await _storage.storeFile(data: u8, filename: filename);
        saved++;
      }
      if (saved == 0) return _cors(Response.badRequest(body: 'No file in request'));
      return _cors(Response.ok('Uploaded $saved file(s)'));
    } catch (e) {
      debugPrint('[WiFiTransfer] Upload error: $e');
      return _cors(Response(500, body: e.toString()));
    } finally {
      _isReceiving = false;
      _uploadCompleteTimer?.cancel();
      _showUploadComplete = true;
      _uploadCompleteTimer = Timer(const Duration(seconds: 3), () {
        _showUploadComplete = false;
        notifyListeners();
      });
      notifyListeners();
    }
  }

  Future<Response> _handleThumbnail(Request request, String itemId) async {
    final thumbPath = _storage.getThumbnailPath(itemId);
    if (thumbPath == null) return _cors(Response.notFound('No thumbnail'));
    final file = File(thumbPath);
    if (!await file.exists()) return _cors(Response.notFound('Not found'));
    final bytes = await file.readAsBytes();
    return _cors(Response.ok(
      bytes,
      headers: {'Content-Type': 'image/jpeg', 'Cache-Control': 'private, max-age=300'},
    ));
  }

  bool _checkPin(Request request) {
    if (_webPin == null || _webPin!.isEmpty) return true;
    final pin = request.url.queryParameters['pin'];
    return pin == _webPin;
  }

  Future<Response> _handleDownload(Request request, String itemId) async {
    if (!_checkPin(request)) return _cors(Response(403, body: 'PIN required'));
    final filePath = _storage.getFilePath(itemId);
    if (filePath == null) return _cors(Response.notFound('Not found'));
    final file = File(filePath);
    if (!await file.exists()) return _cors(Response.notFound('Not found'));
    TransferItem? item;
    for (final i in _storage.items) {
      if (i.id == itemId) { item = i; break; }
    }
    final name = item?.name ?? itemId;
    return _cors(Response.ok(
      file.openRead(),
      headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename="${_escapeHeader(name)}"',
      },
    ));
  }

  String _escapeHeader(String s) => s.replaceAll('"', '\\"').replaceAll('\r', '').replaceAll('\n', '');

  Future<Response> _handleDelete(Request request) async {
    if (!_monetization.isPro) return _cors(Response(403, body: 'Pro required'));
    try {
      final body = await request.read().transform(utf8.decoder).join();
      final id = Uri.splitQueryString(body)['id'];
      if (id == null || id.isEmpty) return _cors(Response.badRequest(body: 'id required'));
      await _storage.deleteItem(id);
      return _cors(Response.ok('OK'));
    } catch (e) {
      debugPrint('[WiFiTransfer] Delete error: $e');
      return _cors(Response(500, body: e.toString()));
    }
  }

  Future<Response> _handleRename(Request request) async {
    if (!_monetization.isPro) return _cors(Response(403, body: 'Pro required'));
    try {
      final body = await request.read().transform(utf8.decoder).join();
      final params = Uri.splitQueryString(body);
      final id = params['id'];
      final name = params['name'];
      if (id == null || id.isEmpty || name == null) return _cors(Response.badRequest(body: 'id and name required'));
      await _storage.renameItem(id, name);
      return _cors(Response.ok('OK'));
    } catch (e) {
      debugPrint('[WiFiTransfer] Rename error: $e');
      return _cors(Response(500, body: e.toString()));
    }
  }

  Future<Response> _handleSetPin(Request request) async {
    if (!_monetization.isPro) return _cors(Response(403, body: 'Pro required'));
    try {
      final body = await request.read().transform(utf8.decoder).join();
      final pin = Uri.splitQueryString(body)['pin'] ?? '';
      _webPin = pin.isEmpty ? null : pin;
      return _cors(Response.ok('OK'));
    } catch (e) {
      return _cors(Response(500, body: e.toString()));
    }
  }

  Future<Response> _handlePinEnabled(Request request) async {
    final enabled = _monetization.isPro && _webPin != null && _webPin!.isNotEmpty;
    return _cors(Response.ok(
      jsonEncode({'enabled': enabled}),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  Future<Response> _handleDownloadAll(Request request) async {
    if (!_checkPin(request)) return _cors(Response(403, body: 'PIN required'));
    final items = _storage.items;
    if (items.isEmpty) {
      return _cors(Response.ok(
        'No files.',
        headers: {'Content-Type': 'text/plain; charset=utf-8'},
      ));
    }
    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp('wifi_transfer_zip_');
      final zipPath = path.join(tempDir.path, 'transfer-files.zip');
      final encoder = ZipFileEncoder();
      encoder.create(zipPath, level: ZipFileEncoder.gzip);
      final usedNames = <String, int>{};
      for (final item in items) {
        final filePath = _storage.getFilePath(item.id);
        if (filePath == null) continue;
        final f = File(filePath);
        if (!await f.exists()) continue;
        String zipName = item.name;
        if (zipName.isEmpty) zipName = item.id;
        final count = (usedNames[zipName] ?? 0) + 1;
        usedNames[zipName] = count;
        if (count > 1) {
          final ext = path.extension(zipName);
          final base = path.basenameWithoutExtension(zipName);
          zipName = ext.isEmpty ? '$base ($count)' : '$base ($count)$ext';
        }
        await encoder.addFile(f, zipName);
      }
      await encoder.close();
      final zipFile = File(zipPath);
      if (!await zipFile.exists()) return _cors(Response(500, body: 'Failed to create zip'));
      Future.delayed(const Duration(minutes: 5), () async {
        try { await tempDir?.delete(recursive: true); } catch (_) {}
      });
      return _cors(Response.ok(
        zipFile.openRead(),
        headers: {
          'Content-Type': 'application/zip',
          'Content-Disposition': 'attachment; filename="transfer-files.zip"',
        },
      ));
    } catch (e) {
      debugPrint('[WiFiTransfer] Download-all error: $e');
      try { await tempDir?.delete(recursive: true); } catch (_) {}
      return _cors(Response(500, body: e.toString()));
    }
  }

  Future<bool> startServer() async {
    if (_isRunning) return true;
    try {
      await _storage.init();
      if (_monetization.isPro) {
        _port = _monetization.preferredPort;
      } else {
        _port = MonetizationService.defaultPort;
      }
      final ip = await _getLocalIP();
      final bindAddress = (ip == 'localhost' || ip == '127.0.0.1')
          ? InternetAddress.anyIPv4
          : InternetAddress(ip);
      final router = Router();
      router.get('/', _handleIndex);
      router.get('/api/items', _handleList);
      router.get('/api/pin-enabled', (Request req) => _handlePinEnabled(req));
      router.get('/thumbnail/<itemId>', (Request req, String itemId) => _handleThumbnail(req, itemId));
      router.post('/upload', _handleUpload);
      router.post('/api/delete', _handleDelete);
      router.post('/api/rename', _handleRename);
      router.post('/api/set-pin', _handleSetPin);
      router.get('/download/<itemId>', (Request req, String itemId) => _handleDownload(req, itemId));
      router.get('/download-all', _handleDownloadAll);

      final handler = Pipeline()
          .addMiddleware(_corsOptionsMiddleware())
          .addMiddleware(_logMiddleware())
          .addHandler(router.call);

      try {
        _server = await shelf_io.serve(handler, bindAddress, _port);
      } catch (e) {
        debugPrint('[WiFiTransfer] Bind failed: $e');
        _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, _port);
      }
      _serverUrl = 'http://$ip:$_port';
      _isRunning = true;
      _mdnsDiscoverable = false;
      _usedNativeMdns = false;
      if (ip != 'localhost' && ip != '127.0.0.1') {
        if (Platform.isIOS || Platform.isAndroid) {
          try {
            final service = MdnsService(
              name: 'PocketServer',
              type: '_http._tcp',
              port: _port,
              hostAddresses: Platform.isAndroid ? [ip] : null,
              attributes: {'path': '/'},
            );
            await MdnsResponder().publishService(service);
            _usedNativeMdns = true;
            _mdnsDiscoverable = true;
            debugPrint('[WiFiTransfer] mDNS (native): discoverable');
          } catch (e) {
            debugPrint('[WiFiTransfer] Native mDNS failed: $e');
          }
        }
        if (!_mdnsDiscoverable) {
          try {
            final mdnsService = await MDNSService.create(
              instance: 'PocketServer',
              service: '_http._tcp',
              port: _port,
              ips: [InternetAddress(ip)],
              txt: ['path=/'],
            );
            _mdnsServer = MDNSServer(MDNSServerConfig(zone: mdnsService));
            await _mdnsServer!.start();
            _mdnsDiscoverable = true;
            debugPrint('[WiFiTransfer] mDNS (dart): discoverable');
          } catch (e) {
            debugPrint('[WiFiTransfer] mDNS dart failed: $e');
          }
        }
      }
      if (_monetization.isPro) {
        await WakelockPlus.enable();
      }
      debugPrint('[WiFiTransfer] Started $_serverUrl');
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('[WiFiTransfer] Start error: $e');
      debugPrint('[WiFiTransfer] $st');
      if (_port < 8090) {
        _port++;
        return startServer();
      }
      notifyListeners();
      return false;
    }
  }

  Middleware _logMiddleware() {
    return (Handler handler) {
      return (Request request) async {
        debugPrint('[WiFiTransfer] ${request.method} ${request.url}');
        return handler(request);
      };
    };
  }

  Future<void> stopServer() async {
    if (!_isRunning || _server == null) return;
    await WakelockPlus.disable();
    if (_usedNativeMdns) {
      try { await MdnsResponder().stopService(); } catch (e) {
        debugPrint('[WiFiTransfer] Native mDNS stop: $e');
      }
      _usedNativeMdns = false;
    }
    if (_mdnsServer != null) {
      try { await _mdnsServer!.stop(); } catch (e) {
        debugPrint('[WiFiTransfer] mDNS stop: $e');
      }
      _mdnsServer = null;
    }
    _mdnsDiscoverable = false;
    try {
      await _server!.close(force: true);
    } catch (e) {
      debugPrint('[WiFiTransfer] Stop error: $e');
    }
    _server = null;
    _serverUrl = null;
    _isRunning = false;
    notifyListeners();
  }
}
