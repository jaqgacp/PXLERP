import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

const SUPABASE_URL = 'http://127.0.0.1:54321';
const SUPABASE_ANON_KEY = 'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH';
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

document.addEventListener('DOMContentLoaded', async () => {
  const form = document.getElementById('login-form');
  const btnLogout = document.getElementById('btn-logout');
  const errorEl = document.getElementById('login-error');
  const successEl = document.getElementById('login-success');

  // Check current session
  const { data: { session } } = await supabase.auth.getSession();
  if (session) {
    successEl.textContent = 'Already logged in as: ' + session.user.email;
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

    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

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
    await supabase.auth.signOut();
    window.location.reload();
  });
});
