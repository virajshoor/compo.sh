"use strict";
const canvas = document.getElementById("demo-canvas");
const buttons = document.querySelectorAll("[data-mode]");
buttons.forEach(button => button.addEventListener("click", () => {
  canvas.dataset.layout = button.dataset.mode;
  buttons.forEach(item => item.setAttribute("aria-pressed", String(item === button)));
  const twoBrowsers = button.dataset.mode === "two-browsers";
  canvas.querySelector(".terminal .window-name").textContent = twoBrowsers ? "Browser · second window" : "Terminal";
  canvas.querySelector(".terminal .window-top > :last-child").textContent = twoBrowsers ? "↗" : "⌥";
}));
