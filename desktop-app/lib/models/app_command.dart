/// The app's commands whose keyboard shortcut can be changed, in the order
/// Settings lists them.
enum AppCommand { receive, send, propose, addAccount, toggleSidebar, nextSidebarItem, previousSidebarItem, refresh }

/// The commands whose keys belong to the system, or to every app on it, and
/// so cannot be given to an [AppCommand]. Settings and Close Window are the
/// app's own, but keep the keys every app gives them.
enum SystemCommand {
  settings,
  closeWindow,
  quit,
  hide,
  hideOthers,
  minimize,
  fullScreen,
  cut,
  copy,
  paste,
  selectAll,
  undo,
  redo,
}
