/* quiz.js — Widget de quiz para las lecciones.
   Uso:
     <div class="quiz" data-correct="2" data-explain="...">
       <p class="quiz-q">Pregunta</p>
       <div class="quiz-opts">
         <button class="quiz-opt">Opción A</button>
         <button class="quiz-opt">Opción B</button>
         <button class="quiz-opt">Opción C</button>
         <button class="quiz-opt">Opción D</button>
       </div>
       <p class="quiz-feedback" aria-live="polite"></p>
     </div>
   data-correct = índice (0-based) de la opción correcta.
   Las opciones deben tener la misma cantidad de palabras.
   Funciona sin importar el orden de carga: delega el click en el
   contenedor del quiz y arranca con DOMContentLoaded si es necesario. */
(function () {
  function activate(quiz) {
    var correct = parseInt(quiz.dataset.correct, 10);
    var opts = quiz.querySelectorAll(".quiz-opt");
    var fb = quiz.querySelector(".quiz-feedback");
    if (!fb || !opts.length) return;

    function answer(idx) {
      var opt = opts[idx];
      opts.forEach(function (o) {
        o.classList.remove("right", "wrong");
      });
      if (idx === correct) {
        opt.classList.add("right");
        fb.textContent = "Correcto. " + (quiz.dataset.explain || "");
      } else {
        opt.classList.add("wrong");
        opts[correct].classList.add("right");
        fb.textContent = "Incorrecto. " + (quiz.dataset.explain || "");
      }
    }

    quiz.addEventListener("click", function (e) {
      var target = e.target;
      while (target && target !== quiz && !target.classList.contains("quiz-opt")) {
        target = target.parentNode;
      }
      if (!target || target === quiz) return;
      var idx = Array.prototype.indexOf.call(opts, target);
      if (idx >= 0) answer(idx);
    });
  }

  function run() {
    document.querySelectorAll(".quiz").forEach(activate);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", run);
  } else {
    run();
  }
})();