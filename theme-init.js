/* Nastaví tému ešte pred vykreslením stránky, aby pri svetlej téme neblikla tmavá.
   Preferencia (dark / light / auto) sa pamätá v zariadení; po prihlásení ju prípadne prepíše nastavenie z účtu. */
(function () {
  var p = "dark";
  try { p = localStorage.getItem("rodinnyTetris_tema") || "dark"; } catch (e) {}
  var svetla = p === "light" || (p === "auto" && window.matchMedia && window.matchMedia("(prefers-color-scheme: light)").matches);
  document.documentElement.setAttribute("data-theme", svetla ? "light" : "dark");
  var m = document.querySelector('meta[name="theme-color"]');
  if (m) m.setAttribute("content", svetla ? "#f3f5fb" : "#0b0e17");
})();
