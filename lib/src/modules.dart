part of august;

/// New type for rewrite. In this case, modules are expected to be instantiated
/// with this type. That is, this is not a factory type.
abstract class Module {
  dynamic get module;
}
