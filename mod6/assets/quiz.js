/* Quiz compartido: click → corrección inmediata + puntaje. Sin dependencias. */
(function(){
  function init(){
    document.querySelectorAll('.quiz').forEach(function(quiz){
      var qs = quiz.querySelectorAll('.q');
      var scoreEl = quiz.querySelector('#score');
      var done = 0, ok = 0;
      qs.forEach(function(q){
        var btns = q.querySelectorAll('button[data-ok]');
        btns.forEach(function(b){
          b.addEventListener('click', function(){
            if(q.classList.contains('answered')) return;
            q.classList.add('answered'); done++;
            var good = (b.getAttribute('data-ok') === '1');
            if(good){ b.classList.add('correct'); ok++; }
            else{
              b.classList.add('wrong');
              q.querySelector('button[data-ok="1"]').classList.add('correct');
            }
            if(scoreEl) scoreEl.textContent = 'Puntaje: ' + ok + ' / ' + qs.length +
              (done === qs.length ? (ok === qs.length ? ' — perfecto, listo para presentar.' : ' — repasá el feedback y reintentá en otra pasada.') : '');
          });
        });
      });
    });
  }
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
