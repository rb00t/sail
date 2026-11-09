const buttons = document.querySelectorAll('[data-copy]');

buttons.forEach((button) => {
  const target = document.querySelector(button.dataset.copy);
  const status = document.getElementById(button.getAttribute('aria-describedby'));
  if (!target) return;

  let reset;

  button.addEventListener('click', async () => {
    const text = target.textContent.trim();
    try {
      await navigator.clipboard.writeText(text);
      button.textContent = 'copied';
      status.textContent = 'Command copied to the clipboard.';
    } catch {
      status.textContent = 'The clipboard is blocked. Select the command and copy it.';
      return;
    }
    clearTimeout(reset);
    reset = setTimeout(() => { button.textContent = 'copy'; }, 1400);
  });
});
