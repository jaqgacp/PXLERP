import { authManager } from './auth-manager.js';

document.addEventListener('DOMContentLoaded', async () => {
  const form = document.getElementById('login-form');
  const btnLogout = document.getElementById('btn-logout');
  const errorEl = document.getElementById('login-error');
  const successEl = document.getElementById('login-success');

  // Check current session
  if (authManager.isAuthenticated()) {
    const user = authManager.getCurrentUser();
    successEl.textContent = 'Already logged in as: ' + (user.email || user.id);
    successEl.style.display = 'block';
    form.style.display = 'none';
    btnLogout.style.display = 'block';
  }

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    errorEl.style.display = 'none';
    successEl.style.display = 'none';

    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;

    const { data, error } = await authManager.signInWithPassword(email, password);

    if (error) {
      errorEl.textContent = 'Login failed: ' + error.message;
      errorEl.style.display = 'block';
    } else {
      successEl.textContent = 'Login successful! Redirecting...';
      successEl.style.display = 'block';
      setTimeout(() => {
        window.location.hash = '#/setup/company-setup/new';
      }, 1000);
    }
  });

  btnLogout.addEventListener('click', async () => {
    await authManager.signOut();
  });
});
