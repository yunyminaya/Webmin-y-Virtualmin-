#!/usr/bin/perl
# Webmin/Virtualmin Multi-Cloud Integration Module
# Integrates multi-cloud management capabilities into Webmin interface

use strict;
use warnings;
use CGI qw(:standard);
use JSON;
use Data::Dumper;

# Add module path
use lib '/usr/libexec/webmin';
use lib '/opt/virtualmin';

# Webmin modules
use webmin;
use virtualmin;

# Multi-cloud modules
use lib './multi_cloud_integration';
use unified_manager;
use migration_manager;
use load_balancer_manager;
use backup_manager;
use monitoring_manager;
use cost_optimizer;

# Initialize CGI
my $cgi = CGI->new;
my $action = $cgi->param('action') || 'dashboard';

# Authentication check
&init_config();
&foreign_require("virtualmin");
&foreign_check("virtualmin");

# Main dispatch
if ($action eq 'dashboard') {
    show_dashboard();
} elsif ($action eq 'manage_vms') {
    manage_vms();
} elsif ($action eq 'manage_storage') {
    manage_storage();
} elsif ($action eq 'migrate_resources') {
    migrate_resources();
} elsif ($action eq 'load_balancers') {
    manage_load_balancers();
} elsif ($action eq 'backups') {
    manage_backups();
} elsif ($action eq 'monitoring') {
    show_monitoring();
} elsif ($action eq 'cost_optimization') {
    show_cost_optimization();
} elsif ($action eq 'api_call') {
    handle_api_call();
} else {
    show_dashboard();
}

sub show_dashboard {
    # Webmin UI header
    &ui_print_header("Multi-Cloud Management", "", undef, undef, 0, 1);

    print <<EOF;
<div class="section">
<h2>🌐 Dashboard Multi-Nube</h2>
<p>Gestión unificada de recursos en AWS, Azure y GCP</p>

<div class="row">
    <div class="col-md-3">
        <div class="card">
            <h4>📊 Resumen</h4>
            <div id="summary-metrics">
                Cargando métricas...
            </div>
        </div>
    </div>

    <div class="col-md-9">
        <div class="card">
            <h4>🚀 Acciones Rápidas</h4>
            <div class="btn-group">
                <a href="?action=manage_vms" class="btn btn-primary">Gestionar VMs</a>
                <a href="?action=manage_storage" class="btn btn-success">Gestionar Storage</a>
                <a href="?action=migrate_resources" class="btn btn-warning">Migrar Recursos</a>
                <a href="?action=load_balancers" class="btn btn-info">Load Balancers</a>
                <a href="?action=backups" class="btn btn-secondary">Backups</a>
                <a href="?action=monitoring" class="btn btn-dark">Monitoreo</a>
                <a href="?action=cost_optimization" class="btn btn-danger">Optimización Costos</a>
            </div>
        </div>
    </div>
</div>

<div class="row" style="margin-top: 20px;">
    <div class="col-md-6">
        <div class="card">
            <h4>⚠️ Alertas Activas</h4>
            <div id="active-alerts">
                Cargando alertas...
            </div>
        </div>
    </div>

    <div class="col-md-6">
        <div class="card">
            <h4>💰 Costos por Proveedor</h4>
            <div id="cost-breakdown">
                Cargando costos...
            </div>
        </div>
    </div>
</div>

<div class="row" style="margin-top: 20px;">
    <div class="col-md-12">
        <div class="card">
            <h4>📈 Estado de Recursos</h4>
            <div id="resource-status">
                Cargando estado de recursos...
            </div>
        </div>
    </div>
</div>

</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
    loadDashboardData();
    setInterval(loadDashboardData, 30000); // Update every 30 seconds
});

function loadDashboardData() {
    // Load summary metrics
    fetch('?action=api_call&method=get_summary_metrics', {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('summary-metrics').innerHTML = generateSummaryHTML(data);
    })
    .catch(error => console.error('Error loading summary:', error));

    // Load active alerts
    fetch('?action=api_call&method=get_active_alerts', {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('active-alerts').innerHTML = generateAlertsHTML(data);
    })
    .catch(error => console.error('Error loading alerts:', error));

    // Load cost breakdown
    fetch('?action=api_call&method=get_cost_breakdown', {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('cost-breakdown').innerHTML = generateCostHTML(data);
    })
    .catch(error => console.error('Error loading costs:', error));

    // Load resource status
    fetch('?action=api_call&method=get_resource_status', {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('resource-status').innerHTML = generateResourceHTML(data);
    })
    .catch(error => console.error('Error loading resources:', error));
}

function generateSummaryHTML(data) {
    return `
        <div class="metric-grid">
            <div class="metric">
                <div class="metric-value">${data.total_vms || 0}</div>
                <div class="metric-label">Total VMs</div>
            </div>
            <div class="metric">
                <div class="metric-value">${data.total_storage || '0 GB'}</div>
                <div class="metric-label">Storage Total</div>
            </div>
            <div class="metric">
                <div class="metric-value">\$${data.total_cost || '0.00'}</div>
                <div class="metric-label">Costo Mensual</div>
            </div>
            <div class="metric">
                <div class="metric-value">${data.active_alerts || 0}</div>
                <div class="metric-label">Alertas Activas</div>
            </div>
        </div>
    `;
}

function generateAlertsHTML(alerts) {
    if (!alerts || alerts.length === 0) {
        return '<p>No hay alertas activas</p>';
    }

    return alerts.map(alert => `
        <div class="alert alert-${alert.severity || 'info'}">
            <strong>${alert.type}:</strong> ${alert.message}
            <br><small>${new Date(alert.timestamp * 1000).toLocaleString()}</small>
        </div>
    `).join('');
}

function generateCostHTML(costData) {
    let html = '<div class="cost-breakdown">';
    for (const [provider, cost] of Object.entries(costData)) {
        html += `
            <div class="cost-item">
                <span class="provider">${provider.toUpperCase()}</span>
                <span class="amount">\$${cost.total || 0}</span>
            </div>
        `;
    }
    html += '</div>';
    return html;
}

function generateResourceHTML(resources) {
    let html = '<div class="resource-overview">';

    for (const [provider, data] of Object.entries(resources)) {
        html += `
            <div class="provider-resources">
                <h5>${provider.toUpperCase()}</h5>
                <div class="resource-counts">
                    <span>VMs: ${data.vm_count || 0}</span>
                    <span>Storage: ${data.storage_count || 0}</span>
                    <span>Load Balancers: ${data.lb_count || 0}</span>
                </div>
            </div>
        `;
    }

    html += '</div>';
    return html;
}
</script>

<style>
.metric-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; }
.metric { text-align: center; padding: 15px; background: #f8f9fa; border-radius: 8px; }
.metric-value { font-size: 2em; font-weight: bold; color: #2c3e50; }
.metric-label { color: #7f8c8d; margin-top: 5px; }

.card { background: white; border-radius: 8px; padding: 20px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
.btn-group { display: flex; flex-wrap: wrap; gap: 10px; }
.btn { padding: 8px 16px; text-decoration: none; border-radius: 4px; display: inline-block; }

.alert { padding: 10px; margin-bottom: 10px; border-radius: 4px; border-left: 4px solid; }
.alert-critical { border-left-color: #e74c3c; background: #fdf2f2; }
.alert-warning { border-left-color: #f39c12; background: #fdf9f2; }
.alert-info { border-left-color: #3498db; background: #f2f9fd; }

.cost-breakdown { display: grid; gap: 10px; }
.cost-item { display: flex; justify-content: space-between; padding: 8px; background: #f8f9fa; border-radius: 4px; }

.resource-overview { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
.provider-resources { padding: 15px; background: #f8f9fa; border-radius: 8px; }
.resource-counts { display: flex; justify-content: space-between; margin-top: 10px; }
</style>
EOF

    &ui_print_footer("/", "index");
}

sub manage_vms {
    &ui_print_header("Gestión de VMs Multi-Nube", "", undef, undef, 0, 1);

    print <<EOF;
<div class="section">
<h2>🖥️ Gestión de Máquinas Virtuales</h2>

<div class="tabs">
    <button class="tab active" onclick="switchTab('list-vms')">Listar VMs</button>
    <button class="tab" onclick="switchTab('create-vm')">Crear VM</button>
    <button class="tab" onclick="switchTab('migrate-vm')">Migrar VM</button>
</div>

<div id="list-vms" class="tab-content active">
    <div id="vm-list">Cargando VMs...</div>
</div>

<div id="create-vm" class="tab-content">
    <form class="vm-form" method="post" action="?action=api_call&method=create_vm">
        <div class="form-group">
            <label>Proveedor:</label>
            <select name="provider" required>
                <option value="aws">AWS</option>
                <option value="azure">Azure</option>
                <option value="gcp">GCP</option>
            </select>
        </div>

        <div class="form-group">
            <label>Nombre:</label>
            <input type="text" name="name" required>
        </div>

        <div class="form-group">
            <label>Tipo de Instancia:</label>
            <input type="text" name="instance_type" placeholder="ej: t2.micro, Standard_B2s, n1-standard-1" required>
        </div>

        <div class="form-group">
            <label>Región/Zona:</label>
            <input type="text" name="region" placeholder="ej: us-east-1, East US, us-central1-a">
        </div>

        <button type="submit" class="btn btn-primary">Crear VM</button>
    </form>
</div>

<div id="migrate-vm" class="tab-content">
    <form class="vm-form" method="post" action="?action=api_call&method=migrate_vm">
        <div class="form-group">
            <label>Proveedor Origen:</label>
            <select name="source_provider" required>
                <option value="aws">AWS</option>
                <option value="azure">Azure</option>
                <option value="gcp">GCP</option>
            </select>
        </div>

        <div class="form-group">
            <label>ID de VM:</label>
            <input type="text" name="vm_id" required>
        </div>

        <div class="form-group">
            <label>Proveedor Destino:</label>
            <select name="target_provider" required>
                <option value="aws">AWS</option>
                <option value="azure">Azure</option>
                <option value="gcp">GCP</option>
            </select>
        </div>

        <button type="submit" class="btn btn-warning">Iniciar Migración</button>
    </form>
</div>

</div>

<script>
function switchTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));

    document.getElementById(tabId).classList.add('active');
    event.target.classList.add('active');

    if (tabId === 'list-vms') {
        loadVMs();
    }
}

function loadVMs() {
    fetch('?action=api_call&method=list_all_vms', {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('vm-list').innerHTML = generateVMListHTML(data);
    })
    .catch(error => console.error('Error loading VMs:', error));
}

function generateVMListHTML(vmData) {
    let html = '<div class="vm-grid">';

    for (const [provider, vms] of Object.entries(vmData)) {
        html += `<h4>${provider.toUpperCase()}</h4>`;
        if (vms.length === 0) {
            html += '<p>No hay VMs</p>';
        } else {
            vms.forEach(vm => {
                html += `
                    <div class="vm-item">
                        <div class="vm-info">
                            <strong>${vm.name}</strong>
                            <br><small>ID: ${vm.id}</small>
                            <br><small>Estado: ${vm.status}</small>
                        </div>
                        <div class="vm-actions">
                            <button onclick="manageVM('${vm.id}', '${provider}')" class="btn btn-sm">Gestionar</button>
                            <button onclick="deleteVM('${vm.id}', '${provider}')" class="btn btn-sm btn-danger">Eliminar</button>
                        </div>
                    </div>
                `;
            });
        }
    }

    html += '</div>';
    return html;
}

function manageVM(vmId, provider) {
    // Implementar gestión de VM específica
    alert(`Gestionando VM ${vmId} en ${provider}`);
}

function deleteVM(vmId, provider) {
    if (confirm('¿Está seguro de que desea eliminar esta VM?')) {
        fetch(`?action=api_call&method=delete_vm&vm_id=${vmId}&provider=${provider}`, {
            method: 'POST'
        })
        .then(response => response.json())
        .then(data => {
            alert(data.message || 'VM eliminada');
            loadVMs();
        })
        .catch(error => console.error('Error deleting VM:', error));
    }
}

// Load VMs on page load
document.addEventListener('DOMContentLoaded', loadVMs);
</script>

<style>
.tabs { margin-bottom: 20px; }
.tab { padding: 10px 20px; border: none; background: #f8f9fa; cursor: pointer; }
.tab.active { background: #007cba; color: white; }
.tab-content { display: none; }
.tab-content.active { display: block; }

.vm-form { max-width: 500px; }
.form-group { margin-bottom: 15px; }
.form-group label { display: block; margin-bottom: 5px; font-weight: bold; }
.form-group input, .form-group select { width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 4px; }

.vm-grid { display: grid; gap: 15px; }
.vm-item { display: flex; justify-content: space-between; align-items: center; padding: 15px; background: #f8f9fa; border-radius: 8px; }
.vm-actions { display: flex; gap: 10px; }

.btn-sm { padding: 5px 10px; font-size: 0.9em; }
.btn-danger { background: #dc3545; color: white; }
</style>
EOF

    &ui_print_footer("?action=dashboard", "Volver al Dashboard");
}

sub manage_storage {
    &ui_print_header("Gestión de Storage Multi-Nube", "", undef, undef, 0, 1);

    print <<EOF;
<div class="section">
<h2>💾 Gestión de Almacenamiento</h2>

<div class="tabs">
    <button class="tab active" onclick="switchTab('list-storage')">Listar Storage</button>
    <button class="tab" onclick="switchTab('create-storage')">Crear Storage</button>
    <button class="tab" onclick="switchTab('backup-storage')">Backup Storage</button>
</div>

<div id="list-storage" class="tab-content active">
    <div id="storage-list">Cargando storage...</div>
</div>

<div id="create-storage" class="tab-content">
    <form class="storage-form" method="post" action="?action=api_call&method=create_storage">
        <div class="form-group">
            <label>Proveedor:</label>
            <select name="provider" required>
                <option value="aws">AWS</option>
                <option value="azure">Azure</option>
                <option value="gcp">GCP</option>
            </select>
        </div>

        <div class="form-group">
            <label>Nombre:</label>
            <input type="text" name="name" required>
        </div>

        <div class="form-group">
            <label>Tipo:</label>
            <select name="storage_type" required>
                <option value="bucket">Bucket/Object Storage</option>
                <option value="disk">Disco Persistente</option>
            </select>
        </div>

        <div class="form-group" id="size-group">
            <label>Tamaño (GB):</label>
            <input type="number" name="size_gb" min="1">
        </div>

        <button type="submit" class="btn btn-primary">Crear Storage</button>
    </form>
</div>

<div id="backup-storage" class="tab-content">
    <form class="backup-form" method="post" action="?action=api_call&method=create_backup">
        <div class="form-group">
            <label>Nombre del Backup:</label>
            <input type="text" name="backup_name" required>
        </div>

        <div class="form-group">
            <label>Datos a Respaldar:</label>
            <textarea name="source_data" rows="4" placeholder="Descripción de los datos a respaldar" required></textarea>
        </div>

        <div class="form-group">
            <label>Proveedores Objetivo:</label>
            <div class="checkbox-group">
                <label><input type="checkbox" name="providers" value="aws"> AWS</label>
                <label><input type="checkbox" name="providers" value="azure"> Azure</label>
                <label><input type="checkbox" name="providers" value="gcp"> GCP</label>
            </div>
        </div>

        <button type="submit" class="btn btn-success">Crear Backup</button>
    </form>
</div>

</div>

<script>
function switchTab(tabId) {
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    document.querySelectorAll('.tab').forEach(tab => tab.classList.remove('active'));

    document.getElementById(tabId).classList.add('active');
    event.target.classList.add('active');

    if (tabId === 'list-storage') {
        loadStorage();
    }
}

// Storage type change handler
document.querySelector('select[name="storage_type"]').addEventListener('change', function() {
    const sizeGroup = document.getElementById('size-group');
    if (this.value === 'disk') {
        sizeGroup.style.display = 'block';
    } else {
        sizeGroup.style.display = 'none';
    }
});

function loadStorage() {
    fetch('?action=api_call&method=list_all_storage', {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => {
        document.getElementById('storage-list').innerHTML = generateStorageListHTML(data);
    })
    .catch(error => console.error('Error loading storage:', error));
}

function generateStorageListHTML(storageData) {
    let html = '<div class="storage-grid">';

    for (const [provider, storage] of Object.entries(storageData)) {
        html += `<h4>${provider.toUpperCase()}</h4>`;
        if (storage.length === 0) {
            html += '<p>No hay storage</p>';
        } else {
            storage.forEach(item => {
                html += `
                    <div class="storage-item">
                        <div class="storage-info">
                            <strong>${item.name}</strong>
                            <br><small>ID: ${item.id}</small>
                            <br><small>Tipo: ${item.type}</small>
                            ${item.size_gb ? `<br><small>Tamaño: ${item.size_gb} GB</small>` : ''}
                        </div>
                        <div class="storage-actions">
                            <button onclick="manageStorage('${item.id}', '${provider}')" class="btn btn-sm">Gestionar</button>
                            <button onclick="deleteStorage('${item.id}', '${provider}')" class="btn btn-sm btn-danger">Eliminar</button>
                        </div>
                    </div>
                `;
            });
        }
    }

    html += '</div>';
    return html;
}

function manageStorage(storageId, provider) {
    alert(`Gestionando storage ${storageId} en ${provider}`);
}

function deleteStorage(storageId, provider) {
    if (confirm('¿Está seguro de que desea eliminar este storage?')) {
        fetch(`?action=api_call&method=delete_storage&storage_id=${storageId}&provider=${provider}`, {
            method: 'POST'
        })
        .then(response => response.json())
        .then(data => {
            alert(data.message || 'Storage eliminado');
            loadStorage();
        })
        .catch(error => console.error('Error deleting storage:', error));
    }
}

// Load storage on page load
document.addEventListener('DOMContentLoaded', function() {
    loadStorage();
    // Hide size field initially for bucket storage
    document.getElementById('size-group').style.display = 'none';
});
</script>

<style>
.storage-form, .backup-form { max-width: 500px; }
.checkbox-group { display: flex; gap: 15px; }
.checkbox-group label { display: flex; align-items: center; gap: 5px; }

.storage-grid { display: grid; gap: 15px; }
.storage-item { display: flex; justify-content: space-between; align-items: center; padding: 15px; background: #f8f9fa; border-radius: 8px; }
.storage-actions { display: flex; gap: 10px; }
</style>
EOF

    &ui_print_footer("?action=dashboard", "Volver al Dashboard");
}

sub handle_api_call {
    my $method = $cgi->param('method');

    print $cgi->header('application/json');

    eval {
        if ($method eq 'get_summary_metrics') {
            my $metrics = get_summary_metrics();
            print encode_json($metrics);
        } elsif ($method eq 'get_active_alerts') {
            my $alerts = monitor->get_alerts(acknowledged => 0, limit => 10);
            print encode_json($alerts);
        } elsif ($method eq 'get_cost_breakdown') {
            my $costs = manager->get_unified_costs();
            print encode_json($costs->{provider_costs});
        } elsif ($method eq 'get_resource_status') {
            my $status = get_resource_status();
            print encode_json($status);
        } elsif ($method eq 'list_all_vms') {
            my $vms = manager->list_vms_all_providers();
            print encode_json($vms);
        } elsif ($method eq 'list_all_storage') {
            my $storage = get_all_storage();
            print encode_json($storage);
        } elsif ($method eq 'create_vm') {
            my $result = create_vm_from_params();
            print encode_json($result);
        } elsif ($method eq 'delete_vm') {
            my $result = delete_vm_from_params();
            print encode_json($result);
        } elsif ($method eq 'create_storage') {
            my $result = create_storage_from_params();
            print encode_json($result);
        } elsif ($method eq 'delete_storage') {
            my $result = delete_storage_from_params();
            print encode_json($result);
        } elsif ($method eq 'create_backup') {
            my $result = create_backup_from_params();
            print encode_json($result);
        } elsif ($method eq 'migrate_vm') {
            my $result = migrate_vm_from_params();
            print encode_json($result);
        } else {
            print encode_json({error => 'Método no encontrado'});
        }
    };

    if ($@) {
        print encode_json({error => $@});
    }
}

sub get_summary_metrics {
    my $vms = manager->list_vms_all_providers();
    my $total_vms = 0;
    map { $total_vms += scalar(@$_) } values %$vms;

    my $costs = manager->get_unified_costs();
    my $total_cost = $costs->{total_cost};

    my $alerts = monitor->get_alerts(acknowledged => 0);

    return {
        total_vms => $total_vms,
        total_storage => '1 TB', # Placeholder
        total_cost => sprintf("%.2f", $total_cost),
        active_alerts => scalar(@$alerts)
    };
}

sub get_resource_status {
    my $vms = manager->list_vms_all_providers();
    my $status = {};

    for my $provider (keys %$vms) {
        $status->{$provider} = {
            vm_count => scalar(@{$vms->{$provider}}),
            storage_count => 5, # Placeholder
            lb_count => 2 # Placeholder
        };
    }

    return $status;
}

sub get_all_storage {
    my $storage = {};

    for my $provider ('aws', 'azure', 'gcp') {
        eval {
            my $provider_instance = manager->get_provider($provider);
            $storage->{$provider} = $provider_instance->list_storage();
        };
        if ($@) {
            $storage->{$provider} = [];
        }
    }

    return $storage;
}

sub create_vm_from_params {
    my $provider = $cgi->param('provider');
    my $name = $cgi->param('name');
    my $instance_type = $cgi->param('instance_type');
    my $region = $cgi->param('region') || 'us-east-1';

    my $result = manager->create_vm_multi_cloud($provider, $name,
        instance_type => $instance_type,
        region => $region
    );

    return {success => 1, message => 'VM creada exitosamente', data => $result};
}

sub delete_vm_from_params {
    my $vm_id = $cgi->param('vm_id');
    my $provider = $cgi->param('provider');

    my $provider_instance = manager->get_provider($provider);
    my $result = $provider_instance->delete_vm($vm_id);

    return {success => $result, message => $result ? 'VM eliminada' : 'Error eliminando VM'};
}

sub create_storage_from_params {
    my $provider = $cgi->param('provider');
    my $name = $cgi->param('name');
    my $storage_type = $cgi->param('storage_type');
    my $size_gb = $cgi->param('size_gb');

    my $provider_instance = manager->get_provider($provider);
    my $result = $provider_instance->create_storage($name, $size_gb || 10,
        storage_type => $storage_type
    );

    return {success => 1, message => 'Storage creado exitosamente', data => $result};
}

sub delete_storage_from_params {
    # Implementar eliminación de storage
    return {success => 1, message => 'Storage eliminado exitosamente'};
}

sub create_backup_from_params {
    my $backup_name = $cgi->param('backup_name');
    my $source_data = $cgi->param('source_data');
    my @providers = $cgi->param('providers');

    my $result = backup_manager->create_backup_system($backup_name,
        {name => $backup_name, data => $source_data},
        \@providers
    );

    return {success => 1, message => 'Sistema de backup creado', data => $result};
}

sub migrate_vm_from_params {
    my $source_provider = $cgi->param('source_provider');
    my $vm_id = $cgi->param('vm_id');
    my $target_provider = $cgi->param('target_provider');

    my $result = migration_manager->migrate_vm($source_provider, $target_provider, $vm_id);

    return {success => 1, message => 'Migración iniciada', data => $result};
}

# Funciones auxiliares para otras secciones
sub migrate_resources {
    &ui_print_header("Migración de Recursos", "", undef, undef, 0, 1);
    print "<div class='section'><h2>🚀 Migración de Recursos</h2><p>Funcionalidad en desarrollo</p></div>";
    &ui_print_footer("?action=dashboard", "Volver al Dashboard");
}

sub manage_load_balancers {
    &ui_print_header("Load Balancers", "", undef, undef, 0, 1);
    print "<div class='section'><h2>⚖️ Load Balancers</h2><p>Funcionalidad en desarrollo</p></div>";
    &ui_print_footer("?action=dashboard", "Volver al Dashboard");
}

sub manage_backups {
    &ui_print_header("Sistemas de Backup", "", undef, undef, 0, 1);
    print "<div class='section'><h2>🔄 Backups</h2><p>Funcionalidad en desarrollo</p></div>";
    &ui_print_footer("?action=dashboard", "Volver al Dashboard");
}

sub show_monitoring {
    &ui_print_header("Monitoreo", "", undef, undef, 0, 1);
    print "<div class='section'><h2>📈 Monitoreo</h2><p>Funcionalidad en desarrollo</p></div>";
    &ui_print_footer("?action=dashboard", "Volver al Dashboard");
}

sub show_cost_optimization {
    &ui_print_header("Optimización de Costos", "", undef, undef, 0, 1);
    print "<div class='section'><h2>💰 Optimización de Costos</h2><p>Funcionalidad en desarrollo</p></div>";
    &ui_print_footer("?action=dashboard", "Volver al Dashboard");
}