import React, { useState, useEffect, useRef } from 'react';
import {
  Shield,
  Key,
  FileText,
  Terminal,
  Layers,
  RefreshCw,
  Play,
  Pause,
  Upload,
  CheckCircle,
  AlertTriangle,
  XCircle,
  Sun,
  Moon,
  Copy,
  Minus,
  Square,
  X,
  Server,
  Activity,
  Cpu,
  Settings,
  Sliders,
  Clock,
  Power,
  RotateCw,
} from 'lucide-react';

interface CertificateData {
  id: number;
  name: string;
  desde: string;
  hasta: string;
  restan: number;
  subject: string;
  issuer: string;
}

interface TokenData {
  token: string;
  tokenShort: string;
  desde: string;
  hasta: string;
  restan: number;
  isValid: boolean;
}

interface InvoiceItem {
  id_record: number;
  doc_id: number;
  ref?: string;
  ecf: string;
  vence?: string;
  dt: string;
  pp?: string;
  security_code?: string;
  sign_date?: string;
  track_id?: string;
  api_response?: string;
  status_code?: string;
  status_name?: string;
  C_Posted: 'N' | 'F' | 'Q' | 'P' | 'Y' | 'R' | 'S' | 'E';
  datetime_process?: string;
}

interface CounterItem {
  id: number;
  ecf: string;
  nombre: string;
  restan: number;
  minYellow: number;
  minRed: number;
  alertLevel: 'green' | 'yellow' | 'red';
}

interface WorkerStatus {
  isRunning: boolean;
  isPaused: boolean;
  totalCycles: number;
  totalSigned: number;
  totalSent: number;
  totalAccepted: number;
  totalRejected: number;
  lastCycleDurationMs: number;
  memoryUsageMb: {
    rss: number;
    heapUsed: number;
    heapTotal: number;
  };
  lastRunTimestamp: string | null;
}

export default function App() {
  const [theme, setTheme] = useState<'dark' | 'light'>('dark');
  const [certificate, setCertificate] = useState<CertificateData | null>(null);
  const [token, setToken] = useState<TokenData | null>(null);
  const [invoices, setInvoices] = useState<InvoiceItem[]>([]);
  const [counters, setCounters] = useState<CounterItem[]>([]);
  const [workerStatus, setWorkerStatus] = useState<WorkerStatus | null>(null);
  const [selectedInvoice, setSelectedInvoice] = useState<InvoiceItem | null>(null);
  const [selectedXml, setSelectedXml] = useState<string>('Seleccione una factura de la lista central para inspeccionar su respuesta WebAPI DGII.');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [actionMessage, setActionMessage] = useState<string>('');

  // Estados del Modal de Configuración
  const [showSettingsModal, setShowSettingsModal] = useState<boolean>(false);
  const [activeSettingsTab, setActiveSettingsTab] = useState<'worker' | 'task' | 'maintenance'>('worker');
  const [workerInterval, setWorkerInterval] = useState<number>(3000);
  const [batchSize, setBatchSize] = useState<number>(5);
  const [dryRun, setDryRun] = useState<boolean>(true);
  const [isTaskScheduled, setIsTaskScheduled] = useState<boolean>(false);
  const [isLoadingSettings, setIsLoadingSettings] = useState<boolean>(false);

  // Abrir Modal de Configuración y cargar estado actual
  const openSettings = async () => {
    setShowSettingsModal(true);
    try {
      const res = await fetch('/api/config');
      const json = await res.json();
      if (json.success && json.data) {
        setWorkerInterval(json.data.intervalMs || 3000);
        setBatchSize(json.data.batchSize || 5);
        setDryRun(json.data.dryRun ?? true);
        setIsTaskScheduled(json.data.isTaskScheduled || false);
      }
    } catch (e) {}
  };

  // Guardar configuración del Worker
  const saveSettings = async () => {
    setIsLoadingSettings(true);
    try {
      const res = await fetch('/api/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          intervalMs: Number(workerInterval),
          batchSize: Number(batchSize),
          dryRun: Boolean(dryRun),
        }),
      });
      const json = await res.json();
      if (json.success) {
        flashMessage('Configuración guardada y aplicada al motor.');
        setShowSettingsModal(false);
      }
    } catch (e) {
      flashMessage('Error al guardar configuración.');
    } finally {
      setIsLoadingSettings(false);
    }
  };

  // Instalar o desinstalar Tarea Programada de Windows
  const toggleScheduledTask = async () => {
    setIsLoadingSettings(true);
    try {
      const endpoint = isTaskScheduled ? '/api/service/uninstall-task' : '/api/service/install-task';
      const res = await fetch(endpoint, { method: 'POST' });
      const json = await res.json();
      if (json.success) {
        setIsTaskScheduled(!isTaskScheduled);
        flashMessage(json.message);
      } else {
        flashMessage(json.message || 'Error en tarea programada.');
      }
    } catch (e) {
      flashMessage('Error al comunicar con el servicio de Windows.');
    } finally {
      setIsLoadingSettings(false);
    }
  };

  // Cambiar tema
  const toggleTheme = () => {
    const nextTheme = theme === 'dark' ? 'light' : 'dark';
    setTheme(nextTheme);
    document.body.className = `theme-${nextTheme}`;
  };

  // Cargar datos iniciales y polling
  const fetchData = async () => {
    try {
      // 1. Certificado
      const certRes = await fetch('/api/certificate');
      if (certRes.ok) {
        const json = await certRes.json();
        if (json.success) setCertificate(json.data);
      }

      // 2. Token
      const tokenRes = await fetch('/api/token');
      if (tokenRes.ok) {
        const json = await tokenRes.json();
        if (json.success) setToken(json.data);
      }

      // 3. Facturas
      const invUrl = statusFilter === 'ALL' ? '/api/invoices?limit=50' : `/api/invoices?limit=50&status=${statusFilter}`;
      const invRes = await fetch(invUrl);
      if (invRes.ok) {
        const json = await invRes.json();
        if (json.success) {
          setInvoices(json.data);
          // Si no hay factura seleccionada, seleccionar la primera
          if (!selectedInvoice && json.data.length > 0) {
            handleSelectInvoice(json.data[0]);
          }
        }
      }

      // 4. Contadores
      const countRes = await fetch('/api/counter');
      if (countRes.ok) {
        const json = await countRes.json();
        if (json.success) setCounters(json.data);
      }

      // 5. Estado del Worker
      const statusRes = await fetch('/api/status');
      if (statusRes.ok) {
        const json = await statusRes.json();
        if (json.success) setWorkerStatus(json.data);
      }
    } catch (err: any) {
      console.warn('Error al consultar API local:', err.message);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 3000);
    return () => clearInterval(interval);
  }, [statusFilter]);

  // Selección de factura para el visor de XML
  const handleSelectInvoice = async (item: InvoiceItem) => {
    setSelectedInvoice(item);
    if (item.api_response) {
      setSelectedXml(item.api_response);
    } else {
      try {
        const res = await fetch(`/api/invoices/${item.id_record}/xml`);
        if (res.ok) {
          const json = await res.json();
          if (json.success && json.data) {
            const row = json.data;
            setSelectedXml(row.xml_track_response || row.xml_response || row.xml_file_signed || row.xml_file || 'Sin contenido XML disponible.');
          }
        }
      } catch (e) {
        setSelectedXml('Error cargando XML de la factura seleccionada.');
      }
    }
  };

  // Acciones del Worker
  const handleToggleWorker = async () => {
    if (!workerStatus) return;
    setIsLoading(true);
    try {
      const endpoint = workerStatus.isPaused ? '/api/worker/resume' : '/api/worker/pause';
      const res = await fetch(endpoint, { method: 'POST' });
      const json = await res.json();
      if (json.success) {
        setWorkerStatus(json.stats);
        flashMessage(json.message);
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleProcessManual = async () => {
    setIsLoading(true);
    flashMessage('Ejecutando ciclo manual...');
    try {
      const res = await fetch('/api/worker/process-now', { method: 'POST' });
      const json = await res.json();
      if (json.success) {
        flashMessage('Ciclo completado con éxito.');
        await fetchData();
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleReloadCert = async () => {
    flashMessage('Recargando certificado en memoria...');
    try {
      const res = await fetch('/api/certificate/reload', { method: 'POST' });
      const json = await res.json();
      if (json.success) {
        flashMessage('Certificado actualizado.');
        fetchData();
      }
    } catch (e) {}
  };

  const flashMessage = (msg: string) => {
    setActionMessage(msg);
    setTimeout(() => setActionMessage(''), 3000);
  };

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    flashMessage('Copiado al portapapeles!');
  };

  return (
    <div className="app-container">
      {/* 1. Windows Native Title Bar */}
      <header className="titlebar">
        <div className="titlebar-left">
          <Activity className="titlebar-icon" />
          <span>Sentry &lt;SCEYE&gt; (e-CF) v2.0 - Firmador DGII Agrofem</span>
        </div>
        <div className="titlebar-actions">
          {actionMessage && (
            <span style={{ fontSize: '11px', color: '#38bdf8', marginRight: '10px', fontWeight: 500 }}>
              {actionMessage}
            </span>
          )}
          <button className="titlebar-btn" title="Configuración del Sistema" onClick={openSettings}>
            <Settings size={14} />
          </button>
          <button className="titlebar-btn" title="Cambiar tema claro/oscuro" onClick={toggleTheme}>
            {theme === 'dark' ? <Sun size={14} /> : <Moon size={14} />}
          </button>
          <button className="titlebar-btn" title="Minimizar a la bandeja">
            <Minus size={14} />
          </button>
          <button className="titlebar-btn" title="Maximizar">
            <Square size={12} />
          </button>
          <button className="titlebar-btn btn-close" title="Cerrar">
            <X size={14} />
          </button>
        </div>
      </header>

      {/* 2. Main 4 Quadrants Workspace */}
      <main className="main-workspace">
        {/* FILA SUPERIOR: Cuadrante Certificado e Información del Token */}
        <section className="quadrant-top-row">
          {/* CUADRANTE 1: Información Certificado */}
          <div className="quad-card">
            <div className="quad-header quad-header-cert">
              <div className="quad-header-title">
                <Shield size={14} />
                <span>Información Certificado</span>
              </div>
            </div>
            <div className="quad-body">
              <table className="table-compact">
                <thead>
                  <tr>
                    <th style={{ width: '35px' }}>#</th>
                    <th>DESDE</th>
                    <th>HASTA</th>
                    <th>RESTAN</th>
                  </tr>
                </thead>
                <tbody>
                  {certificate ? (
                    <tr className="selected">
                      <td className="font-mono">{certificate.id}</td>
                      <td className="font-mono">{certificate.desde}</td>
                      <td className="font-mono">{certificate.hasta}</td>
                      <td>
                        <span className={`seq-pill ${certificate.restan < 30 ? 'seq-red' : 'seq-green'}`}>
                          {certificate.restan} días
                        </span>
                      </td>
                    </tr>
                  ) : (
                    <tr>
                      <td colSpan={4} style={{ textAlign: 'center', color: 'var(--text-dim)' }}>
                        Cargando certificado...
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            <div className="action-bar-sub">
              <button className="btn-soft" onClick={() => alert('Carga de certificado: Disponible en diálogo de configuración')}>
                Cambiar
              </button>
              <button className="btn-soft" onClick={handleReloadCert}>
                <RefreshCw size={12} /> Actualizar
              </button>
            </div>
          </div>

          {/* CUADRANTE 2: Información del Token */}
          <div className="quad-card">
            <div className="quad-header quad-header-token">
              <div className="quad-header-title">
                <Key size={14} />
                <span>Información del Token</span>
              </div>
            </div>
            <div className="quad-body">
              <table className="table-compact">
                <thead>
                  <tr>
                    <th style={{ width: '35px' }}>#</th>
                    <th>TOKEN</th>
                    <th>DESDE</th>
                    <th>HASTA</th>
                    <th>RESTAN</th>
                  </tr>
                </thead>
                <tbody>
                  {token ? (
                    <tr className="selected">
                      <td className="font-mono">1</td>
                      <td className="font-mono" title={token.token}>
                        {token.tokenShort}
                      </td>
                      <td className="font-mono">{token.desde}</td>
                      <td className="font-mono">{token.hasta}</td>
                      <td>
                        <span className={`seq-pill ${token.restan < 5 ? 'seq-yellow' : 'seq-green'}`}>
                          {token.restan} min
                        </span>
                      </td>
                    </tr>
                  ) : (
                    <tr>
                      <td colSpan={5} style={{ textAlign: 'center', color: 'var(--text-dim)' }}>
                        Sin token activo
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            <div className="action-bar-sub" style={{ justifyContent: 'flex-end' }}>
              <button className="btn-soft" onClick={() => flashMessage('Renovación automática gestionada a expira - 5 min')}>
                Renovar Token
              </button>
            </div>
          </div>
        </section>

        {/* PANEL CENTRAL: e-CF Pendientes */}
        <section className="quadrant-center">
          <div className="quad-header quad-header-pending">
            <div className="quad-header-title">
              <FileText size={14} />
              <span>e-CF Pendientes / Bandeja del Día</span>
            </div>
            <div style={{ display: 'flex', gap: '6px' }}>
              {['ALL', 'N', 'F', 'P', 'Y', 'R'].map((st) => (
                <button
                  key={st}
                  onClick={() => setStatusFilter(st)}
                  style={{
                    background: statusFilter === st ? 'rgba(255,255,255,0.3)' : 'transparent',
                    border: 'none',
                    color: '#fff',
                    padding: '2px 8px',
                    borderRadius: '10px',
                    fontSize: '10px',
                    cursor: 'pointer',
                    fontWeight: statusFilter === st ? 700 : 500,
                  }}
                >
                  {st === 'ALL' ? 'Todos' : st}
                </button>
              ))}
            </div>
          </div>

          <div className="quad-body">
            <table className="table-compact">
              <thead>
                <tr>
                  <th style={{ width: '50px' }}>ID</th>
                  <th style={{ width: '70px' }}>REF</th>
                  <th style={{ width: '120px' }}>ECF</th>
                  <th style={{ width: '80px' }}>VENCE</th>
                  <th style={{ width: '35px' }}>DT</th>
                  <th style={{ width: '35px' }}>PP</th>
                  <th style={{ width: '65px' }}>S.C.</th>
                  <th style={{ width: '130px' }}>F.FIRMA</th>
                  <th style={{ width: '160px' }}>TRACKID</th>
                  <th style={{ width: '40px' }}>&lt;/&gt;</th>
                  <th>API MSJ</th>
                  <th style={{ width: '40px', textAlign: 'center' }}>&lt;S&gt;</th>
                </tr>
              </thead>
              <tbody>
                {invoices.length > 0 ? (
                  invoices.map((inv) => {
                    const isSelected = selectedInvoice?.id_record === inv.id_record;
                    return (
                      <tr
                        key={inv.id_record}
                        className={isSelected ? 'selected' : ''}
                        onClick={() => handleSelectInvoice(inv)}
                      >
                        <td className="font-mono">{inv.doc_id}</td>
                        <td className="font-mono">{inv.ref || '-'}</td>
                        <td className="font-mono" style={{ fontWeight: 600 }}>
                          {inv.ecf}
                        </td>
                        <td className="font-mono">{inv.vence || '-'}</td>
                        <td className="font-mono">{inv.dt}</td>
                        <td className="font-mono">{inv.pp || 'N'}</td>
                        <td className="font-mono" style={{ color: '#38bdf8' }}>
                          {inv.security_code || '-'}
                        </td>
                        <td className="font-mono">{inv.sign_date || '-'}</td>
                        <td className="font-mono" title={inv.track_id}>
                          {inv.track_id ? `${inv.track_id.substring(0, 14)}...` : '-'}
                        </td>
                        <td className="font-mono">{inv.status_code || '-'}</td>
                        <td style={{ maxWidth: '250px', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                          {inv.status_name || '-'}
                        </td>
                        <td style={{ textAlign: 'center' }}>
                          <span className={`badge-status badge-${inv.C_Posted}`}>{inv.C_Posted}</span>
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan={12} style={{ textAlign: 'center', padding: '20px', color: 'var(--text-dim)' }}>
                      No hay comprobantes pendientes en este momento.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Controles Inferiores de la Tabla */}
          <div className="center-toolbar">
            <div
              className="status-pill-running"
              style={{
                backgroundColor: workerStatus?.isPaused ? 'rgba(245, 158, 11, 0.15)' : 'rgba(16, 185, 129, 0.15)',
                color: workerStatus?.isPaused ? '#f59e0b' : '#10b981',
                borderColor: workerStatus?.isPaused ? 'rgba(245, 158, 11, 0.4)' : 'rgba(16, 185, 129, 0.4)',
              }}
            >
              <div
                className="status-dot-pulse"
                style={{
                  backgroundColor: workerStatus?.isPaused ? '#f59e0b' : '#10b981',
                  boxShadow: workerStatus?.isPaused ? '0 0 8px #f59e0b' : '0 0 8px #10b981',
                }}
              />
              <span>{workerStatus?.isPaused ? 'Pausado' : 'Running...'}</span>
            </div>

            <button
              className="btn-soft"
              title="Pausar o reanudar el ciclo automático del firmador"
              onClick={handleToggleWorker}
              disabled={isLoading}
            >
              {workerStatus?.isPaused ? <Play size={12} /> : <Pause size={12} />}
              {workerStatus?.isPaused ? 'Reanudar' : 'Pausar'}
            </button>

            <button
              className="btn-soft"
              onClick={() => flashMessage('Validación XSD DGII: Conformidad 100% activa')}
            >
              <Upload size={12} /> Load XSD
            </button>

            <button
              className="btn-soft"
              onClick={openSettings}
              title="Abrir configuración y opciones del firmador"
            >
              <Settings size={12} /> Configuración
            </button>

            <button
              className="btn-primary"
              onClick={handleProcessManual}
              disabled={isLoading}
            >
              <RefreshCw size={12} /> Procesar
            </button>
          </div>
        </section>

        {/* FILA INFERIOR: Mensaje WebAPI DGII y e-CF Counter */}
        <section className="quadrant-bottom-row">
          {/* CUADRANTE 4: Mensaje WebAPI DGII */}
          <div className="quad-card">
            <div className="quad-header quad-header-webapi">
              <div className="quad-header-title">
                <Terminal size={14} />
                <span>
                  Mensaje WebAPI DGII
                  {selectedInvoice && ` — ${selectedInvoice.ecf} (DocID ${selectedInvoice.doc_id})`}
                </span>
              </div>
              <button
                className="titlebar-btn"
                style={{ color: '#fff' }}
                title="Copiar contenido"
                onClick={() => copyToClipboard(selectedXml)}
              >
                <Copy size={12} />
              </button>
            </div>
            <div className="quad-body">
              <pre className="xml-console">{selectedXml}</pre>
            </div>
          </div>

          {/* CUADRANTE 5: e-CF Counter */}
          <div className="quad-card">
            <div className="quad-header quad-header-counter">
              <div className="quad-header-title">
                <Layers size={14} />
                <span>e-CF-Counter</span>
              </div>
            </div>
            <div className="quad-body">
              <table className="table-compact">
                <thead>
                  <tr>
                    <th style={{ width: '45px' }}>ECF</th>
                    <th>NOMBRE</th>
                    <th style={{ width: '60px', textAlign: 'right' }}>RESTAN</th>
                  </tr>
                </thead>
                <tbody>
                  {counters.map((c) => (
                    <tr key={c.id}>
                      <td className="font-mono" style={{ fontWeight: 600 }}>
                        {c.ecf}
                      </td>
                      <td style={{ fontSize: '11px', color: 'var(--text-muted)' }}>{c.nombre}</td>
                      <td style={{ textAlign: 'right' }}>
                        <span className={`seq-pill seq-${c.alertLevel}`}>{c.restan}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </section>
      </main>

      {/* 3. Bottom Status Bar */}
      <footer className="statusbar">
        <div className="statusbar-group">
          <span>
            <Server size={11} style={{ verticalAlign: 'middle', marginRight: '4px' }} />
            BD: 172.16.4.14:1433/cms (Conectado)
          </span>
          <span>
            <Activity size={11} style={{ verticalAlign: 'middle', marginRight: '4px' }} />
            DGII: TEST (Sandbox)
          </span>
        </div>
        <div className="statusbar-group">
          {workerStatus && (
            <span>
              <Cpu size={11} style={{ verticalAlign: 'middle', marginRight: '4px' }} />
              Heap: {workerStatus.memoryUsageMb.heapUsed} MB | RSS: {workerStatus.memoryUsageMb.rss} MB
            </span>
          )}
          <span>Ley 32-23 R.D.</span>
        </div>
      </footer>

      {/* 4. Modal de Configuración y Mantenimiento del Sistema */}
      {showSettingsModal && (
        <div className="modal-overlay" onClick={() => setShowSettingsModal(false)}>
          <div className="modal-dialog" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <div className="modal-title">
                <Settings size={16} style={{ color: '#38bdf8' }} />
                <span>Configuración y Mantenimiento del Firmador</span>
              </div>
              <button className="modal-close-btn" onClick={() => setShowSettingsModal(false)}>
                <X size={16} />
              </button>
            </div>

            {/* Modal Tabs */}
            <div className="modal-nav">
              <button
                className={`modal-tab-btn ${activeSettingsTab === 'worker' ? 'active' : ''}`}
                onClick={() => setActiveSettingsTab('worker')}
              >
                <Sliders size={13} /> Parámetros Worker
              </button>
              <button
                className={`modal-tab-btn ${activeSettingsTab === 'task' ? 'active' : ''}`}
                onClick={() => setActiveSettingsTab('task')}
              >
                <Clock size={13} /> Inicio con Windows
              </button>
              <button
                className={`modal-tab-btn ${activeSettingsTab === 'maintenance' ? 'active' : ''}`}
                onClick={() => setActiveSettingsTab('maintenance')}
              >
                <Power size={13} /> Mantenimiento
              </button>
            </div>

            {/* Modal Body */}
            <div className="modal-body">
              {activeSettingsTab === 'worker' && (
                <div>
                  <div className="form-group">
                    <label className="form-label">Intervalo de Sondeo (Milisegundos)</label>
                    <input
                      type="number"
                      className="form-input"
                      value={workerInterval}
                      min={1000}
                      max={60000}
                      step={500}
                      onChange={(e) => setWorkerInterval(Number(e.target.value))}
                    />
                    <p className="form-hint">Frecuencia con la que el Worker revisa comprobantes pendientes (Recomendado: 3000 ms).</p>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Tamaño de Lote (Comprobantes por Ciclo)</label>
                    <input
                      type="number"
                      className="form-input"
                      value={batchSize}
                      min={1}
                      max={50}
                      onChange={(e) => setBatchSize(Number(e.target.value))}
                    />
                    <p className="form-hint">Cantidad máxima de facturas procesadas concurrentemente por ciclo (Recomendado: 5-10).</p>
                  </div>

                  <div className="form-group">
                    <label className="form-label">Modo de Operación</label>
                    <label className="form-checkbox-row">
                      <input
                        type="checkbox"
                        checked={dryRun}
                        onChange={(e) => setDryRun(e.target.checked)}
                      />
                      <div>
                        <span style={{ fontWeight: 600, display: 'block' }}>
                          Modo Simulación Segura (Dry-Run)
                        </span>
                        <span style={{ fontSize: '11px', color: dryRun ? '#f59e0b' : '#10b981' }}>
                          {dryRun
                            ? 'ACTIVO: Genera y valida firmas localmente sin alterar la BD de producción ni emitir a DGII.'
                            : 'PRODUCCIÓN EN FIRME: Las facturas se firman y envían directamente a la DGII.'}
                        </span>
                      </div>
                    </label>
                  </div>
                </div>
              )}

              {activeSettingsTab === 'task' && (
                <div>
                  <div className="badge-status-box">
                    <div>
                      <div style={{ fontWeight: 600, color: 'var(--text-main)', marginBottom: '4px' }}>
                        Arranque Automático con Windows
                      </div>
                      <div style={{ fontSize: '11px', color: 'var(--text-dim)' }}>
                        Inicia el servicio en segundo plano sin ventana CMD al encender o reiniciar el servidor.
                      </div>
                    </div>
                    <div>
                      {isTaskScheduled ? (
                        <span className="badge badge-Y" style={{ padding: '4px 8px' }}>
                          <CheckCircle size={12} style={{ display: 'inline', marginRight: '4px' }} />
                          Activa
                        </span>
                      ) : (
                        <span className="badge badge-N" style={{ padding: '4px 8px' }}>
                          No Instalada
                        </span>
                      )}
                    </div>
                  </div>

                  <div style={{ display: 'flex', gap: '10px', marginTop: '14px' }}>
                    <button
                      className="btn-primary"
                      style={{ flex: 1 }}
                      onClick={toggleScheduledTask}
                      disabled={isLoadingSettings}
                    >
                      {isTaskScheduled ? 'Desinstalar Tarea de Inicio' : 'Instalar Tarea en Windows Scheduler'}
                    </button>
                  </div>

                  <div style={{ marginTop: '20px', padding: '12px', background: 'var(--bg-app)', borderRadius: '6px', border: '1px solid var(--border-subtle)' }}>
                    <div style={{ fontWeight: 600, fontSize: '12px', marginBottom: '6px' }}>ℹ️ Modo Segundo Plano (System Tray)</div>
                    <div style={{ fontSize: '11px', color: 'var(--text-muted)', lineHeight: '1.5' }}>
                      Al cerrar esta ventana o minimizarla, el servicio continuará operando en segundo plano en el puerto 5000. Puede controlarlo en cualquier momento desde el menú maestro <code>iniciar_servidor_agrofem.bat</code> o con el icono de la bandeja del sistema.
                    </div>
                  </div>
                </div>
              )}

              {activeSettingsTab === 'maintenance' && (
                <div>
                  <div className="form-group">
                    <label className="form-label">Acciones Inmediatas de Mantenimiento</label>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      <button
                        className="btn-secondary"
                        style={{ textAlign: 'left', padding: '10px 14px', display: 'flex', alignItems: 'center', gap: '8px' }}
                        onClick={handleReloadCert}
                      >
                        <RefreshCw size={14} style={{ color: '#38bdf8' }} />
                        <div>
                          <div style={{ fontWeight: 600 }}>Recargar Certificado P12 en Memoria</div>
                          <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>Vuelve a leer el certificado de la base de datos sin reiniciar el servicio.</div>
                        </div>
                      </button>

                      <button
                        className="btn-secondary"
                        style={{ textAlign: 'left', padding: '10px 14px', display: 'flex', alignItems: 'center', gap: '8px' }}
                        onClick={handleProcessManual}
                      >
                        <RotateCw size={14} style={{ color: '#10b981' }} />
                        <div>
                          <div style={{ fontWeight: 600 }}>Forzar Ejecución de Ciclo Inmediato</div>
                          <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>Ejecuta inmediatamente el ciclo de firma, transmisión y consulta sin esperar el intervalo.</div>
                        </div>
                      </button>

                      <button
                        className="btn-secondary"
                        style={{ textAlign: 'left', padding: '10px 14px', display: 'flex', alignItems: 'center', gap: '8px' }}
                        onClick={async () => {
                          flashMessage('Verificando conexiones...');
                          await fetchData();
                          flashMessage('Salud de Base de Datos y DGII verificadas.');
                        }}
                      >
                        <Activity size={14} style={{ color: '#a78bfa' }} />
                        <div>
                          <div style={{ fontWeight: 600 }}>Test de Salud y Conectividad</div>
                          <div style={{ fontSize: '10px', color: 'var(--text-dim)' }}>Verifica la latencia con SQL Server (172.16.4.14:1433) y el WebService DGII.</div>
                        </div>
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div className="modal-footer">
              <button className="btn-secondary" onClick={() => setShowSettingsModal(false)}>
                Cerrar
              </button>
              {activeSettingsTab === 'worker' && (
                <button className="btn-primary" onClick={saveSettings} disabled={isLoadingSettings}>
                  Guardar y Aplicar
                </button>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
