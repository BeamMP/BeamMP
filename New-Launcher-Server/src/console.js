var originalConsole = window.console;
const moment = require('moment');

function updateScroll(){
  var element = document.getElementById("console");
  element.scrollTop = element.scrollHeight;
}

module.exports = {
  log: function(message) {
    var timestamp = "<span class='time'>" + moment().format('hh:mm:ss') + "</span>";
    originalConsole.log(message);
    $("#console").append('<li>'+timestamp + ' | <span class="consoleMessage">' + message+'</span></li>');
    updateScroll();
  },
  warn: function(message) {
    var timestamp = "<span class='time'>" + moment().format('hh:mm:ss') + "</span>";
    originalConsole.log(message);
    $("#console").append('<li>'+timestamp + ' | <span class="consoleMessage warn">' + message+'</span></li>');
    updateScroll();
  },
  err: function(message) {
    var timestamp = "<span class='time'>" + moment().format('hh:mm:ss') + "</span>";
    originalConsole.log(message);
    $("#console").append('<li>'+timestamp + ' | <span class="consoleMessage error">' + message+'</span></li>');
    updateScroll();
  }
}
