// -----------------------------------------------------------------------------
// PXL ERP - Validation Engine
// -----------------------------------------------------------------------------

export class ErpValidation {
  constructor(formElement, errorSummaryElement) {
    this.form = formElement;
    this.errorSummary = errorSummaryElement;
    this.errors = [];
  }

  // Clear all validation errors
  clear() {
    this.errors = [];
    if (this.errorSummary) {
      this.errorSummary.style.display = 'none';
      this.errorSummary.innerHTML = '';
    }
    const errorFields = this.form.querySelectorAll('.erp-field.has-error');
    errorFields.forEach(el => el.classList.remove('has-error'));
  }

  // Add an error for a specific field or general form
  addError(message, fieldId = null) {
    this.errors.push(message);
    if (fieldId) {
      const field = document.getElementById(fieldId);
      if (field) {
        // Add has-error to the closest erp-field wrapper
        const wrapper = field.closest('.erp-field');
        if (wrapper) wrapper.classList.add('has-error');
      }
    }
  }

  // Run HTML5 native validation and aggregate errors
  validateNative() {
    const elements = this.form.querySelectorAll('input, select, textarea');
    let isValid = true;
    
    elements.forEach(el => {
      if (!el.validity.valid) {
        isValid = false;
        const wrapper = el.closest('.erp-field');
        if (wrapper) wrapper.classList.add('has-error');
        
        let label = wrapper ? wrapper.querySelector('label') : null;
        let labelText = label ? label.textContent.replace('*', '').trim() : el.name || el.id;
        
        if (el.validity.valueMissing) {
          this.errors.push(`${labelText} is required.`);
        } else if (el.validity.typeMismatch) {
          this.errors.push(`${labelText} has an invalid format.`);
        } else if (el.validity.rangeUnderflow || el.validity.rangeOverflow) {
          this.errors.push(`${labelText} is out of the allowed range.`);
        } else {
          this.errors.push(`${labelText} is invalid.`);
        }
      }
    });
    
    return isValid;
  }

  // Display aggregated errors
  showErrors() {
    if (this.errors.length > 0 && this.errorSummary) {
      this.errorSummary.style.display = 'block';
      let html = '<strong>Please correct the following errors:</strong><ul>';
      this.errors.forEach(err => {
        html += `<li>${err}</li>`;
      });
      html += '</ul>';
      this.errorSummary.innerHTML = html;
      
      // Scroll to top
      this.errorSummary.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  }

  // Helper to validate and return true if no errors
  isValid() {
    return this.errors.length === 0;
  }
}
