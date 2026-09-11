"use strict";(()=>{document.addEventListener("keydown",e=>{let t=e.target;t&&["INPUT","TEXTAREA"].includes(t.tagName)||e.key==="n"&&document.querySelector("[hx-get*='/notes/new']")?.click()});})();
