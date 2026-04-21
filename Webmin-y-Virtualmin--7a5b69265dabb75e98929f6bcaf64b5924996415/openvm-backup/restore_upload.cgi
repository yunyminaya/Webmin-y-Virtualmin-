#!/usr/bin/perl
# restore_upload.cgi - Interfaz Webmin para restaurar backups automáticamente
# Diseño compatible con tema Authentic de Webmin/Virtualmin
use strict;
use warnings;

# Webmin environment
BEGIN {
    $ENV{'WEBMIN_CONFIG'} ||= "/etc/webmin";
    $ENV{'WEBMIN_VAR'}    ||= "/var/webmin";
}

ReadParse();

# Header
print "Content-type: text/html\n\n";
print qq{<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Restaurar Backup Universal</title>
<link rel="stylesheet" href="/unauthenticated/css/bootstrap.min.css">
<link rel="stylesheet" href="/unauthenticated/css/font-awesome.min.css">
<style>
.restore-container { max-width: 900px; margin: 30px auto; padding: 20px; }
.panel-restore { border: 1px solid #ddd; border-radius: 8px; padding: 25px; background: #fff; box-shadow: 0 2px 10px rgba(0,0,0,.1); }
.panel-restore h2 { color: #333; margin-bottom: 20px; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }
.form-group { margin-bottom: 18px; }
.form-group label { font-weight: 600; color: #555; margin-bottom: 5px; display: block; }
.btn-restore { background: #4CAF50; color: white; border: none; padding: 12px 30px; font-size: 16px; border-radius: 5px; cursor: pointer; }
.btn-restore:hover { background: #45a049; }
.upload-zone { border: 2px dashed #4CAF50; border-radius: 10px; padding: 40px; text-align: center; background: #f9f9f9; cursor: pointer; transition: all .3s; }
.upload-zone:hover { background: #f0f8f0; border-color: #45a049; }
.upload-zone i { font-size: 48px; color: #4CAF50; }
.progress-bar { height: 25px; background: #e0e0e0; border-radius: 5px; overflow: hidden; margin-top: 15px; }
.progress-fill { height: 100%; background: linear-gradient(90deg, #4CAF50, #8BC34A); width: 0%; transition: width .5s; text-align: center; color: white; line-height: 25px; }
.log-output { background: #1e1e1e; color: #0f0; font-family: monospace; padding: 15px; border-radius: 5px; max-height: 400px; overflow-y: auto; font-size: 13px; margin-top: 15px; display: none; }
.status-badge { display: inline-block; padding: 3px 10px; border-radius: 3px; font-size: 12px; font-weight: bold; }
.badge-success { background: #dff0d8; color: #3c763d; }
.badge-error { background: #f2dede; color: #a94442; }
.badge-info { background: #d9edf7; color: #31708f; }
.domain-list { display: flex; flex-wrap: wrap; gap: 10px; margin-top: 10px; }
.domain-card { border: 1px solid #ddd; border-radius: 5px; padding: 10px 15px; background: #fafafa; min-width: 150px; }
.domain-card:hover { background: #f0f8f0; border-color: #4CAF50; }
</style>
</head>
<body>
<div class="restore-container">
<div class="panel-restore">
<h2><i class="fa fa-upload"></i> Restaurar Backup Universal</h2>
<p style="color:#666;">Sube cualquier archivo de backup (.tar.gz, .zip, .tar) y el sistema lo detecta, importa y configura automáticamente.</p>
<p style="color:#888; font-size:13px;">Compatible con: <strong>HestiaCP, cPanel, Plesk, DirectAdmin, Laravel, WordPress</strong> y backups genéricos.</p>

<form action="restore_upload_process.cgi" method="post" enctype="multipart/form-data" id="restoreForm">
<div class="upload-zone" id="dropZone" onclick="document.getElementById('backupFile').click()">
<i class="fa fa-cloud-upload"></i>
<p style="font-size:18px; margin-top:15px; color:#555;">Arrastra tu archivo aquí o haz clic para seleccionar</p>
<p style="color:#999; font-size:13px;">.tar.gz, .tgz, .zip, .tar - Máximo 2GB</p>
<input type="file" name="backup" id="backupFile" accept=".tar.gz,.tgz,.zip,.tar,.gz" style="display:none" onchange="fileSelected(this)">
<p id="fileName" style="margin-top:10px; color:#4CAF50; font-weight:bold; display:none;"></p>
</div>

<div class="form-group" style="margin-top:20px;">
<label>Dominio destino (opcional - se detecta automáticamente):</label>
<input type="text" name="domain" class="form-control" placeholder="ejemplo.com (dejar vacío para autodetectar)">
</div>

<div class="form-group">
<label><input type="checkbox" name="force" value="1"> Sobrescribir dominio existente</label>
</div>

<button type="submit" class="btn-restore" id="submitBtn" disabled>
<i class="fa fa-magic"></i> Restaurar Automáticamente
</button>
</form>

<div id="progressSection" style="display:none; margin-top:20px;">
<h4><i class="fa fa-cog fa-spin"></i> Restaurando...</h4>
<div class="progress-bar"><div class="progress-fill" id="progressBar">0%</div></div>
<div class="log-output" id="logOutput"></div>
</div>

<div id="resultSection" style="display:none; margin-top:20px;">
<div id="resultContent"></div>
</div>

</div>
</div>

<script>
function fileSelected(input) {
    if (input.files && input.files[0]) {
        var file = input.files[0];
        document.getElementById('fileName').textContent = '📎 ' + file.name + ' (' + (file.size/1024/1024).toFixed(1) + ' MB)';
        document.getElementById('fileName').style.display = 'block';
        document.getElementById('submitBtn').disabled = false;
        document.getElementById('dropZone').style.borderColor = '#4CAF50';
        document.getElementById('dropZone').style.background = '#f0f8f0';
    }
}

// Drag and drop
var dropZone = document.getElementById('dropZone');
dropZone.addEventListener('dragover', function(e) { e.preventDefault(); this.style.borderColor = '#45a049'; this.style.background = '#e8f5e9'; });
dropZone.addEventListener('dragleave', function(e) { e.preventDefault(); this.style.borderColor = '#4CAF50'; this.style.background = '#f9f9f9'; });
dropZone.addEventListener('drop', function(e) {
    e.preventDefault();
    document.getElementById('backupFile').files = e.dataTransfer.files;
    fileSelected(document.getElementById('backupFile'));
});

document.getElementById('restoreForm').addEventListener('submit', function(e) {
    e.preventDefault();
    document.getElementById('progressSection').style.display = 'block';
    document.getElementById('logOutput').style.display = 'block';
    
    var formData = new FormData(this);
    var xhr = new XMLHttpRequest();
    
    xhr.upload.addEventListener('progress', function(e) {
        if (e.lengthComputable) {
            var pct = Math.round((e.loaded / e.total) * 50);
            document.getElementById('progressBar').style.width = pct + '%';
            document.getElementById('progressBar').textContent = pct + '% - Subiendo...';
        }
    });
    
    xhr.addEventListener('load', function() {
        document.getElementById('progressBar').style.width = '100%';
        document.getElementById('progressBar').textContent = '100% - Completado';
        document.getElementById('progressBar').style.background = 'linear-gradient(90deg, #4CAF50, #2196F3)';
        
        try {
            var result = JSON.parse(xhr.responseText);
            var html = '<div class="panel-restore"><h3>';
            if (result.success) {
                html += '<span class="status-badge badge-success">✓ RESTAURACIÓN EXITOSA</span></h3>';
                html += '<p><strong>Dominio:</strong> <a href="https://' + result.domain + '" target="_blank">' + result.domain + '</a></p>';
                html += '<p><strong>Usuario:</strong> ' + result.username + '</p>';
                html += '<p><strong>Password:</strong> <code>' + result.password + '</code></p>';
                html += '<p><strong>Tipo detectado:</strong> ' + result.type + '</p>';
                html += '<p><strong>URL:</strong> <a href="https://' + result.domain + '" target="_blank">https://' + result.domain + '</a></p>';
                if (result.admin_url) html += '<p><strong>Admin:</strong> <a href="' + result.admin_url + '" target="_blank">' + result.admin_url + '</a></p>';
            } else {
                html += '<span class="status-badge badge-error">✗ ERROR</span></h3>';
                html += '<p style="color:#a94442;">' + result.error + '</p>';
            }
            html += '</div>';
            document.getElementById('resultContent').innerHTML = html;
            document.getElementById('resultSection').style.display = 'block';
        } catch(ex) {
            document.getElementById('resultContent').innerHTML = '<p>Error procesando respuesta</p>';
            document.getElementById('resultSection').style.display = 'block';
        }
    });
    
    xhr.open('POST', 'restore_upload_process.cgi');
    xhr.send(formData);
    
    // Simulate progress for processing phase
    var pct = 50;
    var interval = setInterval(function() {
        if (pct < 95) { pct += 2; document.getElementById('progressBar').style.width = pct + '%'; document.getElementById('progressBar').textContent = pct + '% - Procesando...'; }
        else clearInterval(interval);
    }, 1000);
});
</script>
</body>
</html>
};
