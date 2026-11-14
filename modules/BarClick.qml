import QtQuick

// Регистрирует target целью клика в баре. Поверх модуля бар держит свою область нажатий (перетаскивание модулей) и
// передаёт клик триггеру triggerPress(button) зарегистрированной цели под курсором (или самого модуля). bar в модуль
// бар вписывает уже после его создания — поэтому регистрация по его появлению, а не в Component.onCompleted.
QtObject {
  id: c
  property var bar: null
  property Item target: null
  property var done: null
  function sync() {
    if (done && done !== bar && typeof done.unregisterClickTarget === "function") done.unregisterClickTarget(target)
    done = null
    if (bar && target && typeof bar.registerClickTarget === "function") { bar.registerClickTarget(target); done = bar }
  }
  onBarChanged: sync()
  onTargetChanged: sync()
  Component.onCompleted: sync()
  Component.onDestruction: if (done && typeof done.unregisterClickTarget === "function") done.unregisterClickTarget(target)
}
