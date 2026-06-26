// -----------------------------------------------------------------------------
// PXL ERP - Form Framework Helper
// -----------------------------------------------------------------------------
import { authManager } from '../auth/auth-manager.js';
import { ErpValidation } from './validation.js';

export class Toast {
  static show(type, message) {
    let container = document.querySelector('.erp-toast-container');
    if (!container) {
      container = document.createElement('div');
      container.className = 'erp-toast-container';
      document.body.appendChild(container);
    }
    const toast = document.createElement('div');
    toast.className = `erp-toast ${type}`;
    toast.textContent = message;
    container.appendChild(toast);
    
    // trigger animation
    setTimeout(() => toast.classList.add('show'), 10);
    setTimeout(() => {
      toast.classList.remove('show');
      setTimeout(() => toast.remove(), 300);
    }, 3000);
  }
  static success(msg) { this.show('success', msg); }
  static error(msg) { this.show('error', msg); }
  static warning(msg) { this.show('warning', msg); }
  static info(msg) { this.show('info', msg); }
}

export class ErpFormHelper {
  constructor(config) {
    this.config = config;
    /*
      config = {
        moduleName: 'Fiscal Year',
        listRoute: '#/setup/fiscal-years',
        onLoad: async () => { ... returns data },
        onSave: async (payload, isNew) => { ... saves and returns true/false },
        buildPayload: () => { ... returns object },
        onInit: () => { ... extra DOM bindings }
      }
    */
    this.mode = this.determineMode();
    this.isDirty = false;
    this.validator = null;
  }

  determineMode() {
    const hash = window.location.hash.split('?')[0];
    if (hash.endsWith('/new')) return 'create';
    if (hash.endsWith('/edit')) return 'edit';
    if (hash.endsWith('/view')) return 'view';
    return 'create';
  }

  async init() {
    this.renderShell();
    this.bindEvents();
    
    this.validator = new ErpValidation(
      document.getElementById('erp-form'),
      document.getElementById('erp-validation-summary')
    );

    // Call custom init hook before loading data
    if (this.config.onInit) {
      await this.config.onInit(this.mode);
    }

    if (this.mode === 'view' || this.mode === 'edit') {
      await this.loadData();
    }

    if (this.mode === 'view') {
      this.enforceReadOnly();
    }
  }

  renderShell() {
    const root = document.getElementById('content');
    // Extract inner form fields provided by form.html
    if (!this.cachedInnerFields) {
      const template = document.getElementById('erp-form-template');
      this.cachedInnerFields = template ? template.innerHTML : '<p>No form template found.</p>';
    }
    
    const titleAction = this.mode === 'create' ? 'New' : this.mode === 'edit' ? 'Edit' : 'View';
    const pageTitle = `${titleAction} ${this.config.moduleName}`;
    
    let toolbarHtml = '';
    if (this.mode === 'view') {
      toolbarHtml = `<button class="btn" id="btn-cancel">Back</button>`;
    } else {
      toolbarHtml = `
        <button class="btn btn-primary" id="btn-save">Save</button>
        <button class="btn" id="btn-save-new">Save & New</button>
        <button class="btn" id="btn-cancel">Cancel</button>
      `;
    }

    const shell = `
      <div class="breadcrumb">
        <a href="#/setup">Setup</a> &rsaquo; 
        <a href="${this.config.listRoute}">${this.config.moduleName}</a> &rsaquo; ${pageTitle}
      </div>
      <div class="page-header">
        <h1>${pageTitle}</h1>
      </div>
      <div class="toolbar">
        ${toolbarHtml}
      </div>
      <div id="auth-status" style="padding: 10px; margin-top: 10px; background: #fff3cd; border: 1px solid #ffeeba; border-radius: 4px; font-size: 14px; display: none;"></div>
      
      <div class="erp-form-container">
        <div class="erp-loading-overlay" id="erp-loader">
          <div class="erp-spinner"></div>
        </div>
        <form id="erp-form" onsubmit="return false;">
          <div class="erp-validation-summary" id="erp-validation-summary"></div>
          ${this.cachedInnerFields}
        </form>
      </div>
      
      <div class="status-footer">
        <span class="status-text" id="page-status">Ready</span>
      </div>
    `;

    root.innerHTML = shell;

    // Check auth for edit/create
    if (this.mode !== 'view') {
      const authStatusEl = document.getElementById('auth-status');
      if (!authManager.isAuthenticated()) {
        authStatusEl.style.backgroundColor = '#f8d7da';
        authStatusEl.style.borderColor = '#f5c6cb';
        authStatusEl.style.color = '#721c24';
        authStatusEl.textContent = 'Not signed in — save disabled';
        authStatusEl.style.display = 'block';
        if (document.getElementById('btn-save')) document.getElementById('btn-save').disabled = true;
        if (document.getElementById('btn-save-new')) document.getElementById('btn-save-new').disabled = true;
      }
    }
  }

  bindEvents() {
    const form = document.getElementById('erp-form');
    
    if (this.mode !== 'view') {
      document.getElementById('btn-save').addEventListener('click', () => this.handleSave(false));
      document.getElementById('btn-save-new').addEventListener('click', () => this.handleSave(true));
      
      // Dirty form detection
      form.addEventListener('input', () => this.isDirty = true);
      form.addEventListener('change', () => this.isDirty = true);
      
      // Setup navigation intercept
      this.beforeUnloadHandler = (e) => {
        if (this.isDirty) {
          e.preventDefault();
          e.returnValue = 'You have unsaved changes. Are you sure you want to leave?';
          return e.returnValue;
        }
      };
      window.addEventListener('beforeunload', this.beforeUnloadHandler);
    }

    document.getElementById('btn-cancel').addEventListener('click', () => {
      if (this.mode !== 'view' && this.isDirty) {
        if (!confirm('You have unsaved changes. Are you sure you want to leave?')) {
          return;
        }
      }
      this.cleanup();
      window.location.hash = this.config.listRoute;
    });
  }

  enforceReadOnly() {
    const form = document.getElementById('erp-form');
    const elements = form.querySelectorAll('input, select, textarea, button:not(.btn-cancel)');
    elements.forEach(el => {
      el.setAttribute('readonly', true);
      el.setAttribute('disabled', true);
      if (el.type === 'checkbox' || el.type === 'radio') {
        el.style.pointerEvents = 'none';
      }
    });
  }

  setLoading(isLoading, text = '') {
    const loader = document.getElementById('erp-loader');
    const status = document.getElementById('page-status');
    if (isLoading) {
      loader.classList.add('active');
      status.textContent = text || 'Processing...';
      if (document.getElementById('btn-save')) document.getElementById('btn-save').disabled = true;
      if (document.getElementById('btn-save-new')) document.getElementById('btn-save-new').disabled = true;
    } else {
      loader.classList.remove('active');
      status.textContent = text || 'Ready';
      if (document.getElementById('btn-save') && authManager.isAuthenticated()) {
        document.getElementById('btn-save').disabled = false;
        document.getElementById('btn-save-new').disabled = false;
      }
    }
  }

  async loadData() {
    if (!this.config.onLoad) return;
    this.setLoading(true, 'Loading data...');
    try {
      await this.config.onLoad();
      this.setLoading(false, 'Data loaded.');
    } catch (err) {
      this.setLoading(false, 'Failed to load data.');
      this.validator.addError('Failed to load data: ' + err.message);
      this.validator.showErrors();
      Toast.error('Failed to load data');
    }
  }

  async handleSave(isSaveAndNew) {
    this.validator.clear();
    
    // 1. Native HTML5 Validation
    if (!this.validator.validateNative()) {
      this.validator.showErrors();
      Toast.error('Please correct the validation errors.');
      return;
    }

    // 2. Custom Payload Building & Validation
    let payload;
    try {
      payload = this.config.buildPayload();
    } catch (err) {
      this.validator.addError(err.message);
      this.validator.showErrors();
      return;
    }

    this.setLoading(true, 'Saving...');
    try {
      await this.config.onSave(payload, this.mode === 'create');
      
      this.isDirty = false;
      Toast.success('Saved successfully.');
      
      if (isSaveAndNew) {
        document.getElementById('erp-form').reset();
        this.mode = 'create';
        // Need to update hash without triggering beforeunload
        history.replaceState(null, '', this.config.listRoute + '/new');
        this.renderShell(); // re-render to update title to New
        this.bindEvents();
        if (this.config.onInit) await this.config.onInit(this.mode);
        this.setLoading(false, 'Ready for next entry.');
      } else {
        this.cleanup();
        window.location.hash = this.config.listRoute;
      }
    } catch (err) {
      this.setLoading(false, 'Save failed.');
      this.validator.addError(err.message);
      this.validator.showErrors();
      Toast.error('Save failed: ' + err.message);
    }
  }

  cleanup() {
    if (this.beforeUnloadHandler) {
      window.removeEventListener('beforeunload', this.beforeUnloadHandler);
    }
  }
}
