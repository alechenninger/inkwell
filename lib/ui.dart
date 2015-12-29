library august.ui;

/// Function which takes a map of module types to "interfaces": objects specific
/// to that module which a UI can use to interact with the current [Run].
typedef dynamic CreateUi(Map interfaces);
